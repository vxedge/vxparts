# Changelog

All notable changes to this project will be documented in this file. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows SemVer
(`../docs/VERSIONING.md`).

## [Unreleased]

### Added

- Repo scaffolding: `README.md`, `AGENTS.md`, `TASKS.md`, `parts/{zone,hpc,gw,agent,svc}/` +
  `scripts/publish/` directory layout.
### Changed

- **`carla-ros-bridge` retired, replaced by `carla-client`** (2026-07-28), published as
  `ghcr.io/vxedge/parts/hpc/ad/middleware/carla-client:0.1.0`,
  `sha256:832dedf3...`. Building the original part is what surfaced the problem:
  `carla-simulator/ros-bridge` master has been frozen since 2022-07-22 and requires CARLA
  0.9.13, while our `carla-server` is pinned to 0.9.15. It built and imported cleanly, which
  is what made it dangerous — a version-mismatched bridge still produces numbers. The
  supported path is `autoware_carla_interface`, which ships inside `autoware_universe` and
  documents exactly 22.04/humble/0.9.15; this part supplies the matching CARLA client.
  The part's VXPN changed with its name: `VXEUS-HADS-M7BO` → `VXECL-HADS-M70H`.

### Added

- Second part published to GHCR (2026-07-28), and the first container one:
  `ghcr.io/vxedge/parts/hpc/ad/middleware/ros2-humble:0.1.0`,
  `sha256:63d1fc55b689c82420c51217b7915438dc9495656de135069e96ad72bb5d75df`. Private package;
  8 `org.vxedge.*` labels intact. Both publish paths — ORAS artifact and OCI container — are
  now proven against a real registry. `carla-ros-bridge` is pinned to this digest, and a build
  confirmed it resolves the dependency from the registry rather than a local tag.
- `publish-container.sh` reports the pushed manifest digest (`podman push --digestfile`),
  which is the value a dependent part or experiment manifest pins. Reading it back off the
  registry would need a pull token — needless for a private package when the push already
  knows the answer.
- **`schema/taxonomy.yaml`** — classes, subtypes, layers, supplier code and digest width
  extracted out of `vxpn.py` into a single reviewable data file. The script now holds the
  algorithm only. Subtypes became class-scoped in the move, so `hpc/qnx` is rejected rather
  than silently encoded; `format.name_digest_chars` became a knob rather than a constant.
  Verified: every existing part number is byte-identical after the refactor.
- **`part.yaml` per part** — licence, upstream pin, GPU need, SBOM slot, free-form
  annotations. Replaces scraping `# license:` comments out of Containerfiles. Identity
  (class/subtype/layer/name) is deliberately *not* restatable there; `vxpn.py meta` rejects a
  declaration that tries, since that duplication is what the no-catalog rule exists to stop.
- `vxpn.py meta` (the single resolver every publish script and build recipe now goes through)
  and `vxpn.py lint` (validates each part against the `build:` contract its layer declares).
- Upstream pins moved from Containerfiles into `part.yaml`; the publish script injects them
  as `--build-arg UPSTREAM=<ref>@<digest>`, so recipes carry no version data at all.
- `scripts/sbom.sh` — CycloneDX generation, deliberately non-blocking: no tooling installed
  means no SBOM, a clear message, and exit 0. `org.vxedge.sbom` is emitted only when the file
  really exists, so a missing SBOM can never become a false claim.
- Subtypes for all five classes (2026-07-28). `agent` and `svc` previously had none, so
  `vxprobe`, `vxtraffic`, the `vxota` crates and the `vxtelemetry` crates — all shipped code —
  could not be numbered; nor could Open5GS/UERANSIM, the components behind the H2 result.
  Added `agent`→`probe`/`load`/`collect`, `svc`→`ota`/`telemetry`/`observability`/`signal`,
  `gw`→`5gc`/`ran`/`dp`, `zone`→`mcu`. Existing part numbers are unaffected.
- `scripts/publish/publish-container.sh` and `scripts/publish/publish-files.sh` — the
  container and config-layer publish paths. Both derive the registry ref and the VXPN from the
  part's directory path. The container script refuses an unpinned base image or a missing
  licence declaration.
- Scaffolding for the eight `hpc/{ad,sim}` parts on phase 2's critical path (READMEs +
  Containerfiles; upstream digests still to resolve).
- First part published to GHCR (2026-07-28):
  `ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle:0.1.0`,
  `sha256:33c9c8d8625bd5c6d1f4d3d0c561fdaa930e057fcd1fb24fb3badb402f25429d`. Private package.
  Round-trip byte-identical; `artifactType` and all seven `org.vxedge.*` annotations preserved
  by GHCR, so the registry serves as the catalogue without a `catalog.yaml`.
- `parts/zone/linux/stack/probe-bundle/build.sh` — the `linux-probe` guest bundle recipe,
  copied from `vxzones/scripts/build-guest-bundle.sh` and adapted to stamp `org.vxedge.*`
  classification fields into `meta.json`. Verified end to end: the bundle boots under
  `qemu-microvm` when pulled fresh from a registry.

### Fixed

- Initramfs builds are now byte-reproducible. The inherited recipe produced a different
  `initrd.img` sha256 on every run (cpio embeds per-file mtimes; gzip embeds a build
  timestamp), so recorded digests identified a build rather than its inputs — at odds with
  the digest-based reproducibility rule these parts depend on. Now pins mtimes via
  `SOURCE_DATE_EPOCH`, sorts cpio member order, and passes `cpio --reproducible` / `gzip -n`.
  **The same bug remains live in `vxzones/scripts/build-guest-bundle.sh`.**
- `build.sh` honours the `KERNEL=` override its own usage comment documented but the
  inherited code ignored (plus a matching `KVER=`, so an overridden kernel can't be
  mislabelled in `meta.json`).
- `scripts/publish/publish-vm-bundle.sh` — ORAS push/pull-verify wrapper for `zone`-class
  bundles: derives manifest annotations from whatever `org.vxedge.*` keys the bundle's
  `meta.json` declares, sets `artifactType: application/vnd.vxedge.part.v1`, and verifies
  the pull round-trip is byte-identical. Validated against a local `registry:2`.

### Known gaps

- No loadable has been published to `ghcr.io/vxedge/parts/...` yet — publishing has only
  been exercised against a local registry, and no tag has been cut.
- The bundle has so far been built only with a stand-in kernel: `/boot/vmlinuz-*` is
  root-only `0600` on the current build host. Everything else in the pipeline is verified.
- The `vxzones` copy of the `linux-probe` recipe is still the one backing live experiments
  (`exp-002`/`exp-002b`) — the `vxparts` copy is not yet the cutover target; see `TASKS.md`
  Migration section.
