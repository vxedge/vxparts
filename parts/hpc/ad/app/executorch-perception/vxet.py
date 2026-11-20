"""vxet: fixed-rate ExecuTorch inference with Prometheus metrics.

Runs one exported model (see export.py) on XNNPACK at a fixed frame rate and serves the
inference latency and deadline misses on /metrics, in the shape vxprobe uses. Warm-up frames are
not counted. On SIGTERM or SIGINT, or when --duration-s ends, it prints one JSON summary to stdout.

Frames follow a camera with a one-frame buffer. Frame k is released at start + k/rate and is due
one period later. A frame that finishes after its due time is a deadline miss. Releases that pass
while a frame is still running are dropped. Each dropped release counts as a frame and a miss, and
the next inference takes the latest release. With --rate-hz 0 frames run back to back, with no
deadline.
"""

import argparse
import hashlib
import json
import math
import os
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import torch
import executorch.extension.pybindings.portable_lib as portable_lib
import executorch.version
from executorch.runtime import Runtime

MODELS = ("mobilenet_v2", "resnet18")
INPUT_SHAPE = (1, 3, 224, 224)
QUANTILES = (("0.5", 0.5, "p50"), ("0.9", 0.9, "p90"), ("0.99", 0.99, "p99"), ("0.999", 0.999, "p999"))
SUB_BITS = 11  # 2048 sub-buckets per power of two: under 0.1 % relative error


class Histogram:
    """Log-linear histogram of nanosecond values, in the manner of HdrHistogram."""

    def __init__(self) -> None:
        self.counts: dict[int, int] = {}
        self.n = 0
        self.mean = 0.0
        self.m2 = 0.0
        self.max = 0

    def record(self, v: int) -> None:
        shift = max(0, v.bit_length() - SUB_BITS)
        top = ((v >> shift) + 1) << shift  # the bucket's upper edge: no quantile under-reports
        self.counts[top] = self.counts.get(top, 0) + 1
        self.n += 1
        d = v - self.mean
        self.mean += d / self.n
        self.m2 += d * (v - self.mean)
        self.max = max(self.max, v)

    def quantile(self, q: float) -> int:
        rank = max(1, math.ceil(q * self.n))
        seen = 0
        for top in sorted(self.counts):
            seen += self.counts[top]
            if seen >= rank:
                return min(top - 1, self.max)
        return self.max

    def stddev(self) -> float:
        return math.sqrt(self.m2 / self.n) if self.n else 0.0

    def copy(self) -> "Histogram":
        h = Histogram()
        h.counts, h.n, h.mean, h.m2, h.max = dict(self.counts), self.n, self.mean, self.m2, self.max
        return h


class State:
    def __init__(self, model: str, period_s: float, threads: int) -> None:
        self.lock = threading.Lock()
        self.model = model
        self.period_s = period_s
        self.threads = threads
        self.hist = Histogram()
        self.frames = 0
        self.misses = 0

    def render(self) -> str:
        # Copy under the lock, compute outside it: the inference loop takes the same lock after
        # every frame, and a scrape must not hold it while it walks the buckets.
        with self.lock:
            h, frames, misses = self.hist.copy(), self.frames, self.misses
        label = f'model="{self.model}"'
        lines = [
            f"vxexecutorch_frames_total{{{label}}} {frames}",
            f"vxexecutorch_deadline_misses_total{{{label}}} {misses}",
            f"vxexecutorch_period_seconds{{{label}}} {self.period_s}",
            f"vxexecutorch_threads{{{label}}} {self.threads}",
        ]
        if h.n:
            for name, q, _ in QUANTILES:
                lines.append(
                    f'vxexecutorch_inference_seconds{{{label},quantile="{name}"}} '
                    f"{h.quantile(q) / 1e9}"
                )
            lines.append(f"vxexecutorch_inference_seconds_max{{{label}}} {h.max / 1e9}")
            lines.append(f"vxexecutorch_inference_seconds_mean{{{label}}} {h.mean / 1e9}")
            lines.append(f"vxexecutorch_inference_seconds_stddev{{{label}}} {h.stddev() / 1e9}")
        return "\n".join(lines) + "\n"

    def summary(self, args: argparse.Namespace, pte_sha256: str, measured_s: float) -> dict:
        with self.lock:
            h, frames, misses = self.hist.copy(), self.frames, self.misses
        us = lambda ns: round(ns / 1e3, 1)  # noqa: E731
        return {
            "model": self.model,
            "rate_hz": args.rate_hz,
            "threads": self.threads,
            "allowed_cpus": len(os.sched_getaffinity(0)),
            "measured_s": round(measured_s, 3),
            "frames": frames,
            "deadline_misses": misses,
            "inference_us": {
                **{key: us(h.quantile(q)) for _, q, key in QUANTILES},
                "max": us(h.max),
                "mean": us(h.mean),
                "stddev": us(h.stddev()),
            }
            if h.n
            else None,
            "executorch": executorch.version.__version__,
            "executorch_commit": executorch.version.git_version,
            "pte_sha256": pte_sha256,
        }


def serve(state: State, listen: str) -> None:
    host, _, port = listen.rpartition(":")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path != "/metrics":
                self.send_error(404)
                return
            body = state.render().encode()
            self.send_response(200)
            self.send_header("content-type", "text/plain; version=0.0.4")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_: object) -> None:
            pass

    server = ThreadingHTTPServer((host or "0.0.0.0", int(port)), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()


def sleep_until(t_ns: int) -> None:
    while (left := t_ns - time.monotonic_ns()) > 0:
        time.sleep(left / 1e9)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--model", choices=MODELS, required=True)
    p.add_argument("--rate-hz", type=float, default=30.0, help="frame rate; 0 runs back to back")
    p.add_argument(
        "--threads", type=int, default=0, help="XNNPACK threads; 0 keeps one per allowed CPU"
    )
    p.add_argument("--duration-s", type=float, default=0.0, help="measured time; 0 runs until stopped")
    p.add_argument("--warmup-s", type=float, default=5.0, help="frames run first and not counted")
    p.add_argument("--metrics-listen", default="0.0.0.0:9470")
    p.add_argument("--models-dir", default="/models")
    args = p.parse_args()
    if args.rate_hz < 0 or args.threads < 0 or args.duration_s < 0 or args.warmup_s < 0:
        p.error("--rate-hz, --threads, --duration-s and --warmup-s must not be negative")

    if args.threads:
        portable_lib._unsafe_reset_threadpool(args.threads)
    threads = portable_lib._threadpool_get_thread_count()
    pte = os.path.join(args.models_dir, f"{args.model}.pte")
    with open(pte, "rb") as f:
        pte_sha256 = hashlib.sha256(f.read()).hexdigest()
    method = Runtime.get().load_program(pte).load_method("forward")
    torch.manual_seed(0)
    frame = [torch.randn(*INPUT_SHAPE)]

    period_ns = round(1e9 / args.rate_hz) if args.rate_hz else 0
    state = State(args.model, period_ns / 1e9, threads)
    serve(state, args.metrics_listen)

    stop = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stop.set())

    warm_end = time.monotonic_ns() + round(args.warmup_s * 1e9)
    while time.monotonic_ns() < warm_end and not stop.is_set():
        method.execute(frame)
        if period_ns:
            time.sleep(period_ns / 1e9)

    t0 = time.monotonic_ns()
    end_at = t0 + round(args.duration_s * 1e9) if args.duration_s else None
    k = 0
    while not stop.is_set():
        release = t0 + k * period_ns
        # Back to back, every release is t0: the clock, not the release, ends the run.
        if end_at is not None and (release if period_ns else time.monotonic_ns()) >= end_at:
            break
        if period_ns:
            sleep_until(release)
        start = time.monotonic_ns()
        method.execute(frame)
        done = time.monotonic_ns()
        missed = 1 if period_ns and done > release + period_ns else 0
        dropped = 0
        if period_ns:
            latest = (done - t0) // period_ns
            dropped = max(0, latest - k - 1)
            k = max(k + 1, latest)
        else:
            k += 1
        with state.lock:
            state.hist.record(done - start)
            state.frames += 1 + dropped
            state.misses += missed + dropped
    measured_s = (time.monotonic_ns() - t0) / 1e9
    json.dump(state.summary(args, pte_sha256, measured_s), sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
