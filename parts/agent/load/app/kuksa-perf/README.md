# agent/load/app/kuksa-perf

Eclipse Kuksa's `databroker-perf`, the client that drives a Kuksa databroker with providers and subscribers
and reports its latency. An experiment runs it against the signal plane a vehicle places.

## What it is

- [kuksa-perf](https://github.com/eclipse-kuksa/kuksa-perf) at commit `aa6fba0` (main, 2025-07-28), built
  from source with upstream's `Cargo.lock` (`--locked`), Apache-2.0. Its `LICENSE` and `NOTICE.md` travel in
  the image under `/app/`.
- Why a commit and not a release: in the 0.3.2 release (2024-12-12) the `kuksa.val.v2` provider never claims
  its signals, so databroker 0.7.1 aborts it, and `--operation actuate` is in no release.
- Builder `rust:1.88-slim-bookworm` and runtime `debian:bookworm-slim`, both pinned by digest.
- Path `/app/databroker-perf`, which is also the entrypoint. `--version` prints 0.3.2: upstream had not
  bumped its version at this commit.

## What it is not

- Not a vehicle application: a measurement load.
- Not an upstream release: move to one when a release carries what this commit does.
- x86_64 only, for now.

## Published

`ghcr.io/vxedge/parts/agent/load/app/kuksa-perf:0.1.0`, `sha256:1e894b9d7de05d41059d711871b17ae3023497933ad88f05f29f903000c7ba73`.

## Build and publish

```sh
./scripts/publish/publish-container.sh parts/agent/load/app/kuksa-perf 0.1.0
```
