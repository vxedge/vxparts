# agent/load/app/dds-perf

`ddsperf`, the load and latency tool that ships with Eclipse Cyclone DDS. An experiment runs one instance
per node to put DDS traffic (RTPS over UDP) on a vehicle's network and to read throughput, loss and
round-trip latency from it.

## What it is

- [Cyclone DDS](https://github.com/eclipse-cyclonedds/cyclonedds) 11.1.0 (released 2026-11-09), commit
  `179ae6f`, built from source. The build checks the clone against the pinned commit.
- Licence: EPL-2.0 OR BSD-3-Clause (upstream's "Eclipse Distribution License 1.0" is the BSD 3-Clause
  text). Upstream's `LICENSE` and `NOTICE.md` travel in the image under `/opt/cyclonedds/`.
- Builder and runtime are `debian:bookworm-slim`, pinned by digest.
- The image holds `ddsperf` and `libddsc` under `/opt/cyclonedds/`. The entrypoint is
  `/opt/cyclonedds/bin/ddsperf`.
- Built with `ENABLE_SSL=OFF` and `ENABLE_SECURITY=OFF`: plain RTPS, no TLS and no DDS Security.

## What it is not

- Not a vehicle application: a measurement load.
- Not a ROS 2 node. It speaks DDS with its own topic types, so it loads the network the way DDS traffic
  does without standing in for a specific application.
- x86_64 only, for now.

## Modes

`ddsperf [OPTIONS] MODE...`, with one or more modes per process:

| Mode | What it does |
|---|---|
| `pub [RATE] [size N]` | publishes samples, for example `pub 1000Hz size 1k` |
| `sub` | subscribes and reports rate, throughput and lost samples each second |
| `ping [RATE]` | sends pings and reports round-trip latency percentiles each second |
| `pong` | answers pings |

`-D SECONDS` ends the run. `-u` switches from reliable to best-effort. `ddsperf help` prints the rest.

Peers find each other with DDS discovery, which uses UDP multicast by default. On a network that does
not carry multicast, give Cyclone DDS a peer list through the `CYCLONEDDS_URI` environment variable.

## Published

`ghcr.io/vxedge/parts/agent/load/app/dds-perf:0.1.0`, `sha256:fb4dd05b876ae028fdae662443b269b92a4bedb2ff9ed70520f1a5351a4cc363`.

## Build

```sh
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/agent/load/app/dds-perf 0.1.0
```

Without `VXPARTS_NO_PUSH=1` the script also pushes the image.

## Verified 2026-11-13 (11.1.0)

- The local build was clean, and all 9 `org.vxedge.*` labels were intact.
- `vxpn.py lint` and `vxpn.py scan` pass, with no part-number collision.
- Smoke test under rootless Podman, two containers in one pod:
  - `ping` against `pong` for 10 s reported round-trip latency percentiles every second;
  - `pub 1000Hz size 1k` against `sub` reported 1.00 kS/s of 1024-byte samples with none lost.
- Not verified yet: a run between two nodes of a vehicle, across a gateway slice.
