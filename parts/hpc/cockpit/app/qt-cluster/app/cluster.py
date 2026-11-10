#!/usr/bin/env python3
"""qt-cluster: a QML instrument cluster on a vehicle's Kuksa signal plane.

Subscribes to three VSS signals over kuksa.val.v2 (the generated stubs kuksa-client ships) and shows
them in Cluster.qml, rendered offscreen. An HTTP endpoint shows that it runs:
  GET /state.json      the values as QML holds them, and whether the subscription is live
  GET /screenshot.png  the cluster as rendered now
Configuration is by environment, with defaults for running beside the databroker on one device:
  CLUSTER_DATABROKER (127.0.0.1:55555), CLUSTER_LISTEN (0.0.0.0:8080).
"""

import json
import os
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import grpc  # noqa: E402
from kuksa.val.v2 import val_pb2 as val  # noqa: E402
from kuksa.val.v2 import val_pb2_grpc as val_grpc  # noqa: E402
from PySide6.QtCore import QBuffer, QIODevice, QObject, Property, Qt, QTimer, QUrl, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (so the root object is a QQuickWindow)

SPEED = "Vehicle.Speed"
SOC = "Vehicle.Powertrain.TractionBattery.StateOfCharge.Current"
GEAR = "Vehicle.Powertrain.Transmission.CurrentGear"
HERE = os.path.dirname(os.path.abspath(__file__))


def log(msg):
    print(f"qt-cluster: {msg}", file=sys.stderr, flush=True)


def scalar(datapoint):
    v = datapoint.value
    kind = v.WhichOneof("typed_value")
    return None if kind is None else getattr(v, kind)


class Cluster(QObject):
    """The values QML binds to. Set only on the GUI thread, through the queued `incoming` signal."""

    changed = Signal()
    incoming = Signal(str, float)
    link = Signal(bool)

    def __init__(self):
        super().__init__()
        self._speed, self._soc, self._gear, self._connected = 0.0, 0.0, 0, False
        self.incoming.connect(self._apply, Qt.QueuedConnection)
        self.link.connect(self._set_connected, Qt.QueuedConnection)

    @Slot(str, float)
    def _apply(self, path, value):
        if path == SPEED:
            self._speed = value
        elif path == SOC:
            self._soc = value
        elif path == GEAR:
            self._gear = int(value)
        self.changed.emit()

    @Slot(bool)
    def _set_connected(self, up):
        self._connected = up
        self.changed.emit()

    speed = Property(float, lambda self: self._speed, notify=changed)
    soc = Property(float, lambda self: self._soc, notify=changed)
    gear = Property(int, lambda self: self._gear, notify=changed)
    connected = Property(bool, lambda self: self._connected, notify=changed)


def subscribe_forever(cluster, server):
    """Subscribe, push each update to the GUI thread, and reconnect if the stream ends."""
    # Each attempt gets its own subchannel pool and a short backoff: gRPC's shared pool keeps a failed
    # connection in exponential backoff (up to 120 s), so a databroker that restarted would stay
    # unreachable to every new channel long after it came back.
    options = [
        ("grpc.use_local_subchannel_pool", 1),
        ("grpc.initial_reconnect_backoff_ms", 500),
        ("grpc.max_reconnect_backoff_ms", 2000),
    ]
    while True:
        channel = grpc.insecure_channel(server, options=options)
        try:
            stub = val_grpc.VALStub(channel)
            stream = stub.Subscribe(val.SubscribeRequest(signal_paths=[SPEED, SOC, GEAR]))
            stream.initial_metadata()  # returns once the databroker has accepted the subscription
            cluster.link.emit(True)
            for resp in stream:
                for path, dp in resp.entries.items():
                    got = scalar(dp)
                    if got is not None:
                        cluster.incoming.emit(path, float(got))
        except grpc.RpcError as e:
            log(f"subscription to {server} ended: {e.code().name}; retrying")
        finally:
            channel.close()
        cluster.link.emit(False)
        time.sleep(1)


class Renderer(QObject):
    """Runs grabs on the GUI thread for the HTTP threads."""

    request = Signal(object)

    def __init__(self, window):
        super().__init__()
        self.window = window
        self.request.connect(self._grab, Qt.QueuedConnection)

    @Slot(object)
    def _grab(self, box):
        try:
            img = self.window.grabWindow()
            buf = QBuffer()
            buf.open(QIODevice.WriteOnly)
            img.save(buf, "PNG")
            box["png"] = bytes(buf.data())
            box["state"] = {
                "speed": self.window.property("speed"),
                "soc": self.window.property("soc"),
                "gear": self.window.property("gear"),
                "connected": self.window.property("connected"),
            }
        except Exception as e:  # noqa: BLE001 - reported to the HTTP caller, never kills the GUI loop
            box["error"] = str(e)
        finally:
            box["done"].set()


def serve(renderer, listen):
    host, port = listen.rsplit(":", 1)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path not in ("/state.json", "/screenshot.png"):
                self.send_error(404)
                return
            box = {"done": threading.Event()}
            renderer.request.emit(box)
            if not box["done"].wait(5) or "error" in box:
                self.send_error(503, box.get("error", "renderer busy"))
                return
            if self.path == "/state.json":
                body, kind = json.dumps(box["state"]).encode(), "application/json"
            else:
                body, kind = box["png"], "image/png"
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    ThreadingHTTPServer((host, int(port)), Handler).serve_forever()


def main():
    server = os.environ.get("CLUSTER_DATABROKER", "127.0.0.1:55555")
    listen = os.environ.get("CLUSTER_LISTEN", "0.0.0.0:8080")
    app = QGuiApplication(sys.argv)
    cluster = Cluster()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("cluster", cluster)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "Cluster.qml")))
    if not engine.rootObjects():
        log("Cluster.qml failed to load")
        return 1
    renderer = Renderer(engine.rootObjects()[0])
    threading.Thread(target=subscribe_forever, args=(cluster, server), daemon=True).start()
    threading.Thread(target=serve, args=(renderer, listen), daemon=True).start()
    # As PID 1 the process gets no default SIGTERM action, so it exits on its own handler. Python runs
    # handlers between bytecodes, and Qt's event loop runs none, so a timer lets it in.
    signal.signal(signal.SIGTERM, lambda *_: os._exit(0))
    tick = QTimer()
    tick.timeout.connect(lambda: None)
    tick.start(200)
    log(f"rendering; databroker {server}; http {listen}")
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
