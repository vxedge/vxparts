# agent/load/app/vxtraffic

The traffic generator an experiment runs as competing load: `vxtraffic --target <ip:port> --bandwidth-mbps
<n> --duration-s <s>` sends UDP at a set rate from wherever its container's network namespace is.

## What it is

- `vxtraffic` from the [vxagents](https://github.com/vxedge/vxagents) v0.1.1 release (commit `563961e`), the
  x86_64 GNU build, verified against the release tarball's sha256 before it is packaged.
- On `debian:bookworm-slim`, pinned by digest: the release binary needs glibc 2.34 or later.
- Path `/vxtraffic`, which is also the entrypoint.

## What it is not

- Not a vehicle application: a measurement load.
- x86_64 only, for now.

## Build and publish

```sh
./parts/agent/load/app/vxtraffic/stage-release.sh
./scripts/publish/publish-container.sh parts/agent/load/app/vxtraffic 0.1.1
```
