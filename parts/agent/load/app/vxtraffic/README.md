# agent/load/app/vxtraffic

The traffic generator an experiment runs as competing load: `vxtraffic --target <ip:port> --bandwidth-mbps
<n> --duration-s <s>` sends UDP at a set rate from wherever its container's network namespace is.

## What it is

- `vxtraffic` from the [vxagents](https://github.com/vxedge/vxagents) v0.2.3 release (commit `5e97e9f`), the
  x86_64 GNU build, verified against the release tarball's sha256 before it is packaged.
- On `debian:bookworm-slim`, pinned by digest: the release binary needs glibc 2.34 or later.
- Path `/vxtraffic`, which is also the entrypoint.

## What it is not

- Not a vehicle application: a measurement load.
- x86_64 only, for now.

## Published

- `ghcr.io/vxedge/parts/agent/load/app/vxtraffic:0.2.0`, `sha256:77956df1c4a4781d513a3d4e388fe91147bf5bc460aac59419da605370d81858`
- `0.1.1` (vxagents v0.1.1), `sha256:be310378c1f330969072669fb24a991b26c2a991dc02f23c81056c8fc98f2c3c`

## Build and publish

```sh
./parts/agent/load/app/vxtraffic/stage-release.sh
./scripts/publish/publish-container.sh parts/agent/load/app/vxtraffic 0.2.3
```
