# AGENTS.md — vxedge/vxparts

The unified loadable registry for the vxedge platform: zone VM/RTOS bundles, central-compute
container images, gateway/TCU images, and agent binaries — every loadable the platform boots,
in one repo, published to `ghcr.io/vxedge/parts/...` via OCI/ORAS. Supersedes the former
`zones-legacy` (zone VM images) / `compute-legacy` (compute containers) split, which was by deployment
mechanism (VM vs container), not domain (see `TASKS.md` Track P for the rationale and
migration plan). Master spec: `../docs/ARCHITECTURE.md` §6 (zone/compute schema), §9
(virtualization stack), §10 (compute model).

## Two files decide everything

- **`schema/taxonomy.yaml`** — the SSOT for classes, subtypes, layers, supplier code, and
  digest width. `scripts/vxpn.py` holds the *algorithm*; this file holds the *vocabulary*.
  Adding a subtype is a reviewable data change, never a code change. Changing an existing
  `code:` or `name_digest_chars` renumbers parts and is a breaking change.
- **`parts/<...>/part.yaml`** — one per part: licence, upstream pin, GPU need, SBOM slot,
  extra annotations. It never restates class/subtype/layer/name; those come from the path.

Everything else — the publish scripts, the build recipes — reads these two and hardcodes
nothing. `vxpn.py meta <part-dir>` is the single resolver both go through.

## What lands here

- **Loadables**, one directory per part: `parts/<class>/<subtype>/<layer>/<name>/` — build
  recipe + `part.yaml` + README only, no composition data (see Classification below).
- **Publish scripts**, one per artifact kind, in `scripts/publish/`: container push
  (docker/podman) for `hpc`/`gw`-class parts, ORAS push for VM/kernel/QNX/AAOS bundles.
- **What does NOT land here**: which part goes into which zone/vehicle. That composition is
  the vehicle/experiment manifest's job (`vxperiments`), per the workspace's
  single-source-of-truth rule. There is deliberately no `catalog.yaml` index in this repo —
  the OCI/ORAS registry itself is the discoverable catalogue.

## Classification (IFEC-LRU-derived)

Every part is identified by **class / subtype / layer**, encoded both as its directory path
and as `org.vxedge.*` OCI annotations stamped at push time:

- **class**: `zone` | `hpc` | `gw` | `agent` | `svc` | `veh` | `ctl`
- **subtype**: for `zone` — `qnx` | `zephyr` | `freertos` | `linux` | `aaos`; for `hpc` —
  `ad` | `cockpit` | `motion` | `sim`; for `gw` — `tcu` | `nos`; for `veh` — `car`; for `ctl`
  — `schema`
- **layer**: `firmware` | `os` | `hypervisor` | `middleware` | `app` | `config` | `stack`
  (`stack` = a composite part, see below)

The pull path is the addressable location and the source of truth:
`ghcr.io/vxedge/parts/<class>/<subtype>/<layer>/<name>:<semver>`. Alongside it, each part
carries a **VXPN** — an ARINC-665-shaped part number (`VXE7G-ZLNX-SHAE`) *computed from* that
path by `scripts/vxpn.py`, never mapped to it by a side table. Use the VXPN in bills of
software, labels, and anywhere a number gets retyped (it has check characters); use the path
to pull; pin the digest for reproducibility. Full rationale and the ARINC 665 / UN R156
provenance: **`PART-NUMBERING.md`**.

A full loaded stack (e.g. `parts/zone/qnx/stack/safety-baseline:2.1.0`) publishes as one OCI
image index over its constituent os/middleware/config parts, so it's a single pullable unit.

## Rules

- All published images/bundles are tagged with SHA256 digests, never `latest`
  (reproducibility rule, ARCHITECTURE.md §13).
- Keep loadables minimal: agents from `vxagents` are injected per experiment, not baked into
  a part.
- Guests (`zone`-class parts) must boot under the vxedge backends: libvirt domain (default) or
  raw-QEMU microvm. Every recipe documents which `backend:` values it supports
  (`zone-backend-contract` skill).
- Licensing hygiene: QNX and AAOS artifacts follow their upstream licenses — never commit QNX
  binaries or other licensed artifacts; commit recipes and fetch instructions only.
- **Optimize `hpc`/`gw`-class container definitions for GPU pass-through and TensorRT
  runtime** (workspace NVIDIA rule): explicit `resources.gpu: passthrough | mig-slice`,
  pinned CUDA/TensorRT versions, digests only.
- C++ is the default language for ROS2/DDS/DeepStream/TensorRT code here (§15 policy); Rust
  for zone-side agents/tooling.
- Images/bundles are loadable workloads, not services: OTA/telemetry service code lives in
  `vxota`/`vxtelemetry`, referenced via experiment manifests, not duplicated here.

## Skill targeting

- `zone-backend-contract` — the guest-bundle contract every `zone`-class part (QNX/AAOS/real
  Zephyr/FreeRTOS/Linux) must satisfy: boot cmdline, digest `meta.json`, per-backend
  documentation. Shared with `vxedge`, which owns the other half of the same contract.
- `deepstream-dev` / `deepstream-generate-pipeline` — target `hpc`-class perception pipelines,
  tracking configs, multi-stream camera matrices.
- `ros2-dds-patterns` — target `hpc/ad` transport/QoS choices, carla-ros-bridge wiring,
  closed-loop actuation.
- `jetson-device` — target both `zone`-class (virtual ECU) and `hpc`-class (containerized
  compute) profiling: memory auditing, latency profiling, edge telemetry.
- `testbed-quality` — the OEM-adoption bar (reproducibility, fidelity honesty, interface
  stability, standards legibility) applies to every part published here.
