# parts/svc/signal/app/kuksa-databroker

The VSS/Kuksa signal plane (`docs/TASKS.md` buildout priority-5 item, 2026-08-05: "the
`SignalBinding` model already parses `vss`/`dbc` fields end to end — nothing plugged into that
slot yet ... pure content, not a design problem"). This part is that first plug: Eclipse Kuksa's
databroker, the reference in-vehicle VSS server the manifest schema's `vss:` field targets.

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

- `upstream.ref: ghcr.io/eclipse-kuksa/kuksa-databroker:0.7.0`
- `upstream.digest`: resolved 2026-08-05 via `oras resolve
  ghcr.io/eclipse-kuksa/kuksa-databroker:0.7.0` (manifest-list digest — the image is
  multi-arch).
- Version: `0.7.0`, the latest release as of pinning (confirmed via
  `gh api repos/eclipse-kuksa/kuksa-databroker/releases/latest`, published 2026-07-03).
- Confirmed via `podman inspect` against the pulled image (not assumed from documentation):
  entrypoint `/app/databroker`, listens `0.0.0.0:55555` (gRPC, the only `ExposedPorts` entry),
  ships VSS release **6.0** metadata baked in
  (`KUKSA_DATABROKER_METADATA_FILE=vss_release_6.0.json`).

## License

**Apache-2.0** — confirmed both via the upstream repo's GitHub SPDX metadata and the pulled
image's own `org.opencontainers.image.licenses` label. No redistribution caveat, unlike the
`gw/5gc`/`gw/ran` siblings (AGPL-3.0) or QNX/AAOS.

## Build

```
../../../../../scripts/publish/publish-container.sh svc/signal/app/kuksa-databroker 0.1.0
# or, for a local build without publishing:
VXPARTS_NO_PUSH=1 ../../../../../scripts/publish/publish-container.sh svc/signal/app/kuksa-databroker 0.1.0
```

## What this part does *not* yet do

Landing the databroker container is the plane's foundation, not the whole feature. Still
`todo`, tracked in `vxparts/TASKS.md`/`docs/TASKS.md`: a Kuksa client wired into zone
guests/agents to actually publish `vss:`-bound signals, CAN/SocketCAN restbus emulation feeding
it, and any manifest-level wiring beyond the schema field already parsing. This part makes those
next steps buildable against a real, pinned, boot-tested server — it doesn't implement them.

## Verified 2026-08-05

`VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/svc/signal/app/kuksa-databroker
0.1.0` built clean; all 9 `org.vxedge.*` labels confirmed intact. Standalone smoke test: ran the
built image with `-p 15555:55555`, confirmed via logs it actually started — "Starting Kuksa
Databroker 0.7.0", populated metadata from `vss_release_6.0.json`, "Listening on
0.0.0.0:55555" — and stayed up. `vxpn.py lint`/`scan` both pass with no collisions. Full
VSS/CAN integration (a manifest-driven `vss:` path actually feeding this broker) is separate,
later work, out of scope here.
