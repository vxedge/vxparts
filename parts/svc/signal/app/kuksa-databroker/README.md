# parts/svc/signal/app/kuksa-databroker

The VSS/Kuksa signal plane: Eclipse Kuksa's databroker, the reference in-vehicle VSS server
the manifest schema's `vss:` field targets.

Classification: `class=svc`, `subtype=signal`, `layer=app`.

## Greenfield — no existing pin anywhere else in the workspace

Checked before authoring this part (2026-08-05): `vxedge`, `vxtelemetry`, `vxparts`, `vxagents`,
`docs` — nothing anywhere hardcodes a Kuksa image, version, or client crate. The only two hooks
that already existed were the taxonomy slot itself (`svc.signal`, code `SIG`,
`schema/taxonomy.yaml`) and the manifest schema field
(`SignalBinding.vss: Option<String>` — `vxedge-core::model`/`workspace.rs`, a per-device COVESA
VSS path string, parsed but not yet consumed by anything running). This part is the first real
content against both.

## Upstream pin

Thin relabel (like `hpc/ad/middleware/ros2-humble`) of Eclipse Kuksa's own published, multi-arch
OCI image — no `build: recipe` non-OCI workaround needed, unlike the two `gw/5gc`/`gw/ran`
siblings landed alongside this part in the same pass.

- `upstream.ref: ghcr.io/eclipse-kuksa/kuksa-databroker:0.7.1`
- `upstream.digest`: `sha256:529d8c6d3cc223362667672978bcb8f92c4d356b25aedd336e7a2e004d7279bd`,
  resolved 2026-11-03 via `oras resolve ghcr.io/eclipse-kuksa/kuksa-databroker:0.7.1`
  (manifest-list digest: amd64, arm64, riscv64).
- Version: `0.7.1`, the latest release as of pinning (published 2026-08-26). It is a maintenance
  release: no flag changes, more robust handling of providers that give empty or delayed
  responses, and opentelemetry 0.32. The previous pin was 0.7.0,
  `sha256:9ace2824719ba7c05929f0af4827d9b25fa5ca7b2e0d58d0acff95885c649d6d`.
- Read from the 0.7.1 image config with `oras` (not assumed from documentation): entrypoint
  `/app/databroker`, listens `0.0.0.0:55555` (gRPC, the only `ExposedPorts` entry), ships VSS
  release **6.0** metadata as the default (`KUKSA_DATABROKER_METADATA_FILE=vss_release_6.0.json`),
  with `vss_release_5.1.json` alongside it.

**This part does not set what runs.** The vehicle documents and the `signal_plane` example in
`docs/ARCHITECTURE.md` pin the upstream image by digest directly, so bumping this part changes
nothing that a `vehicle up` starts. Those pins move in their own changes.

## License

**Apache-2.0** — confirmed both via the upstream repo's GitHub SPDX metadata and the 0.7.1
image's own `org.opencontainers.image.licenses` label. No redistribution caveat, unlike the
`gw/5gc`/`gw/ran` siblings (AGPL-3.0) or QNX/AAOS.

## Build

```
../../../../../scripts/publish/publish-container.sh svc/signal/app/kuksa-databroker 0.2.0
# or, for a local build without publishing:
VXPARTS_NO_PUSH=1 ../../../../../scripts/publish/publish-container.sh svc/signal/app/kuksa-databroker 0.2.0
```

## What this part does *not* do

The databroker runs as the signal-plane stage of `vehicle up` on vxedge `main` (not in a
release yet), pinned from upstream as described above. No zone guest or agent runs a Kuksa
client that publishes `vss:`-bound signals, no CAN/SocketCAN restbus emulation feeds it, and
manifest-level wiring stops at the schema field parsing. This part is a pinned, boot-tested
server only.

## Publishing

This part has not been published to the registry yet. It is one of the choices in the manual
`publish` workflow.

Its SBOM is upstream's own: the CycloneDX 1.4 file Kuksa's build puts in the image at
`/app/sbom.json`, 317 components for 0.7.1. `part.yaml` names it as `sbom.from_image`, and
`scripts/sbom.sh` copies it out of the pinned digest before the publish, so the image carries the
`org.vxedge.sbom` label. The relabelled image keeps the file at `/app/sbom.json`. A scanner is no
use here: syft 1.55.0 finds no components in the static binary.

## Verified 2026-08-05 (0.7.0)

`VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/svc/signal/app/kuksa-databroker
0.1.0` built clean locally; all 9 `org.vxedge.*` labels confirmed intact. Standalone smoke
test: ran the built image with `-p 15555:55555`, confirmed via logs it actually started —
"Starting Kuksa Databroker 0.7.0", populated metadata from `vss_release_6.0.json`, "Listening
on 0.0.0.0:55555" — and stayed up. `vxpn.py lint`/`scan` both pass with no collisions.
CI's own `build-containers` job hadn't independently exercised this part as of the initial
landing commit — a regression in the `gw/ran/os/ueransim` sibling (fixed the same day) made `set -e` abort the job before reaching this part alphabetically.
Full
VSS/CAN integration (a manifest-driven `vss:` path actually feeding this broker) is out of
scope here.
