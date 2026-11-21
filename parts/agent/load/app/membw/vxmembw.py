"""vxmembw: memory-bandwidth load with Prometheus metrics.

Each of --workers processes copies one buffer of --buffer-mib MiB into another in a loop, with
numpy's copyto. A buffer much larger than the last-level cache sends every copy to DRAM, so the
workers load the memory bus that the node shares with others. The copy rate is served on /metrics.
On SIGTERM or SIGINT, or when --duration-s ends, it prints one JSON summary to stdout.

Pin the container to the CPUs the load should run on. The workers do not pin themselves.
"""

import argparse
import json
import multiprocessing as mp
import os
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np

MIB = 1 << 20


def worker(buffer_bytes: int, copied, stop) -> None:
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    src = np.ones(buffer_bytes, dtype=np.uint8)
    dst = np.empty_like(src)
    while not stop.is_set():
        np.copyto(dst, src)
        with copied.get_lock():
            copied.value += buffer_bytes


def serve(listen: str, render) -> None:
    host, _, port = listen.rpartition(":")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path != "/metrics":
                self.send_error(404)
                return
            body = render().encode()
            self.send_response(200)
            self.send_header("content-type", "text/plain; version=0.0.4")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_: object) -> None:
            pass

    server = ThreadingHTTPServer((host or "0.0.0.0", int(port)), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--workers", type=int, default=1, help="copy processes")
    p.add_argument("--buffer-mib", type=int, default=64, help="buffer copied by each worker")
    p.add_argument("--duration-s", type=float, default=0.0, help="run time; 0 runs until stopped")
    p.add_argument("--metrics-listen", default="0.0.0.0:9471")
    args = p.parse_args()
    if args.workers < 1 or args.buffer_mib < 1 or args.duration_s < 0:
        p.error("--workers and --buffer-mib must be at least 1, --duration-s not negative")

    buffer_bytes = args.buffer_mib * MIB
    ctx = mp.get_context("fork")
    copied = ctx.Value("Q", 0)
    stop = ctx.Event()
    procs = [
        ctx.Process(target=worker, args=(buffer_bytes, copied, stop), daemon=True)
        for _ in range(args.workers)
    ]

    def render() -> str:
        return (
            f"vxmembw_copied_bytes_total {copied.value}\n"
            f"vxmembw_workers {args.workers}\n"
            f"vxmembw_buffer_bytes {buffer_bytes}\n"
        )

    serve(args.metrics_listen, render)
    done = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: done.set())

    t0 = time.monotonic()
    for proc in procs:
        proc.start()
    done.wait(args.duration_s or None)
    stop.set()
    for proc in procs:
        proc.join(timeout=5)
        if proc.is_alive():
            proc.kill()
    elapsed = time.monotonic() - t0
    json.dump(
        {
            "workers": args.workers,
            "buffer_mib": args.buffer_mib,
            "allowed_cpus": len(os.sched_getaffinity(0)),
            "seconds": round(elapsed, 3),
            "copied_bytes": copied.value,
            "copy_gib_per_s": round(copied.value / elapsed / (1 << 30), 2),
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
