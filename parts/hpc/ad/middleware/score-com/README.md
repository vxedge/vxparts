# hpc/ad/middleware/score-com — `VXEDE-HADS-M3QW`

Eclipse S-CORE communication, the `mw::com` middleware and its LoLa shared-memory binding, with
`vxlola`, a tool that measures how long one event takes from one process to another.

## What it is

- [eclipse-score/communication](https://github.com/eclipse-score/communication) v0.6.0, commit
  `c5efd74`, Apache-2.0. Built from source with Bazel inside the devcontainer image that release
  pins, `ghcr.io/eclipse-score/devcontainer` by digest. The build checks the clone against the
  release commit. Upstream's `LICENSE` and `NOTICE` travel in the image under
  `/opt/vxlola/score-communication/`.
- `vxlola` (`src/vxlola.cpp`, Apache-2.0) is this part's own code. It is built in the
  communication tree as `score/mw/com/vxlola`, against the public `mw::com` API.
  - The sender fills a sample of up to 1 MiB, stamps it with the monotonic clock just before
    `Send()`, and sends at a fixed rate.
  - The receiver is woken by the event's receive handler. It reads every cache line of the
    payload and then stamps it.
  - Both run on one host clock, so the difference is the one-way latency, notification and
    payload read included. The receiver prints one JSON line: the size received, the count,
    samples lost, and the latency's min, p50, p90, p99, p99.9, max and mean in nanoseconds.
- The runtime base is `debian:trixie-slim`, pinned by digest, plus `libatomic1`.

## What it is not

- Not across ECUs. LoLa is shared-memory IPC: sender and receiver run on one node, sharing
  `/dev/shm`. Crossing a slice would need S-CORE's SOME/IP gateway, which has no release yet.
- Not a statement about S-CORE on production hardware or a real-time kernel. It measures the
  build and host it runs on.
- x86_64 only, for now.

## Run

```
vxlola-run                     sweep: one JSON line per payload size (the default)
vxlola-run send ARGS...        the sender alone:   --size BYTES --rate HZ [--duration S]
vxlola-run recv ARGS...        the receiver alone: --count N [--warmup N] [--timeout S]
```

| Variable | Meaning | Default |
|---|---|---|
| `VXLOLA_SIZES` | payload sizes for the sweep, in bytes | `64 1024 16384 65536 262144 1048576` |
| `VXLOLA_RATE_HZ` | send rate | `1000` |
| `VXLOLA_COUNT` | samples measured per size | `10000` |
| `VXLOLA_WARMUP` | samples discarded first | `100` |
| `VXLOLA_CONFIG` | the `mw::com` configuration | `/opt/vxlola/etc/mw_com_config.json` |

The sample type holds up to 1 MiB, with 16 slots, so `/dev/shm` needs about 20 MiB. Podman's default
64 MiB is enough.

## Published

`ghcr.io/vxedge/parts/hpc/ad/middleware/score-com:0.1.0`, `sha256:6155f2f8b1106e865568e322115d3d6ecf1581953a419822b6d623976b415674`.

## Verified 2026-11-13

The published image ran its sweep (64 B to 1 MiB, 10000 samples per size at 1 kHz) three times
idle and three times beside memory-bandwidth load on other cores: every run completed, with the
receiver reporting the size the sender set.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/hpc/ad/middleware/score-com 0.1.0
```

The Bazel step fetches GCC 15 and the rest of the toolchain on every build, which takes most of
the build's time.
