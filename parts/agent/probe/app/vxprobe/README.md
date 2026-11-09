# agent/probe/app/vxprobe

The probe reflector a container node runs as its payload: `vxprobe reflect` answers vxedge's flow probes on
UDP `:9800`, and `/vxprobe send` drives them from inside the node. busybox provides the shell and `wget` the
flow checks use.

## What it is

- `vxprobe` from the [vxagents](https://github.com/vxedge/vxagents) v0.2.0 release (commit `60ba555`), the
  x86_64 GNU build, verified against the release tarball's sha256 before it is packaged.
- busybox from the official `busybox:1.37.0-musl` image (static, so independent of the base glibc), pinned by digest.
- On `debian:bookworm-slim`, pinned by digest: the release binary needs glibc 2.34 or later.
- Paths: `/vxprobe`, `/bin/busybox`. Entrypoint `vxprobe reflect`.

## What it is not

- Not a vehicle application: a measurement payload.
- x86_64 only, for now.

## Build and publish

```sh
./parts/agent/probe/app/vxprobe/stage.sh
./scripts/publish/publish-container.sh parts/agent/probe/app/vxprobe 0.2.0
```
