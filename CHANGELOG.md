# Changelog

All notable changes to this project will be documented in this file. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows SemVer
([VERSIONING](https://github.com/vxedge/docs/blob/main/VERSIONING.md)).

## [Unreleased]

### Changed

- `agent/probe/app/vxprobe` and `agent/load/app/vxtraffic` package the vxagents v0.2.0 release (commit `60ba555`,
  x86_64 tarball sha256 `55b4bf3b…`): vxprobe adds a cumulative RTT histogram (`vxprobe_rtt_seconds_bucket`,
  `_sum`, `_count`); its existing series and summary are unchanged. Both parts move to 0.2.0, published as
  `agent/probe/app/vxprobe:0.2.0` (`sha256:860dc44caff3553f19e932ec7af181ca0f265340abb0c0f1e722794a3468bfd1`) and
  `agent/load/app/vxtraffic:0.2.0` (`sha256:77956df1c4a4781d513a3d4e388fe91147bf5bc460aac59419da605370d81858`).
- `agent/probe/app/vxprobe`: its stage script is `stage-release.sh`, the name CI runs before a build check, so CI now
  builds the part instead of failing on an unstaged binary.
- `schema/taxonomy.yaml`: the `zone` class drops a subtype no part uses. No part number changes. The
  class-scoped example in `PART-NUMBERING.md` and `vxpn.py` is now `hpc/zephyr`; `AGENTS.md`, `README.md`,
  `NOTICE` and part READMEs name only shipped guest images.
- `zone/aaos/stack/cuttlefish-auto`: `attach.yaml` runs `sh start.sh`, `sh status.sh` and `sh stop.sh`, so the
  adapter starts after travelling in a package, which keeps no execute bit.

### Added

- `parts/hpc/cockpit/app/qt-cluster`: a Qt Quick (QML) instrument cluster on the vehicle's Kuksa signal plane,
  rendered offscreen. It subscribes over `kuksa.val.v2` to speed, gear and battery charge, and serves
  `/state.json` (the values as QML holds them) and `/screenshot.png` on `:8080`. PySide6 6.10.1 and
  kuksa-client 0.6.0, pinned by hash, on `python:3.12-slim` pinned by digest.
- `parts/agent/load/app/vxtraffic`: the traffic generator an experiment runs as competing load, `vxtraffic` from
  the vxagents v0.1.1 release (x86_64 GNU build, tarball sha256 verified) on `debian:bookworm-slim` pinned by
  digest. Entrypoint `/vxtraffic`. Published as `ghcr.io/vxedge/parts/agent/load/app/vxtraffic:0.1.1`,
  `sha256:be310378c1f330969072669fb24a991b26c2a991dc02f23c81056c8fc98f2c3c`.
- `parts/agent/load/app/kuksa-perf`: Eclipse Kuksa's `databroker-perf`, built from source at upstream commit
  `aa6fba0` (`--locked`), because the 0.3.2 release's `kuksa.val.v2` provider is aborted by databroker 0.7.1
  and `--operation actuate` is in no release. Builder and runtime images pinned by digest. Entrypoint
  `/app/databroker-perf`. Published as `ghcr.io/vxedge/parts/agent/load/app/kuksa-perf:0.1.0`,
  `sha256:1e894b9d7de05d41059d711871b17ae3023497933ad88f05f29f903000c7ba73`.
- `parts/zone/linux/stack/probe-bundle-aarch64`: the `linux-probe` guest for aarch64, from pinned Ubuntu 26.04
  arm64 packages and a static aarch64 vxprobe, for `qemu-microvm`'s aarch64 path (vxedge #106).
  Reproducible: two builds are byte-identical. Published as
  `ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle-aarch64:0.1.0`,
  `sha256:e7a187368acedbd3a16fc61383ad2b760a6b0c4ac710976b4643be9ec718c187`.
- `parts/zone/aaos/stack/cuttlefish-auto` is now also the `attach` adapter for vxedge 0.9.1 or later
  (`attach.yaml`, `start.sh`, `status.sh`, `stop.sh`, `vhal-proxy-none.sh`), as `vx-reference-sedan-03` runs it:
  10 of 10 vxAPI gate runs on 2026-11-08.
- `parts/svc/signal/app/vxvhal` 0.1.1, packaging the vxvhal 0.1.1 release, which stops on SIGTERM:
  `ghcr.io/vxedge/parts/svc/signal/app/vxvhal:0.1.1`,
  `sha256:41ee94eaa596c59dafc3e934fe3014b0ee8af3084ac1fb4a94d02644b92c744e`.
- `parts/svc/signal/app/vxvhal`: the Vehicle HAL server of an Android Automotive zone, vxvhal from the
  v0.1.0 release (static musl, checksum verified by `stage-release.sh`) with its default mapping, on
  `scratch`. Published as `ghcr.io/vxedge/parts/svc/signal/app/vxvhal:0.1.0`,
  `sha256:313f44bd558be6783287f45fa45c2439d336951e2d65f4ca5c2df63ce6f85423`.
- `parts/agent/probe/app/vxprobe`: the probe reflector payload of a container node, `vxprobe` from the
  vxagents v0.1.1 release with a static busybox for the flow checks. Published as
  `ghcr.io/vxedge/parts/agent/probe/app/vxprobe:0.1.1`,
  `sha256:b3f22650146dcae004589d311fcd8f231bd2e058f8cb50a7d2a766519210fd6d`.
- `parts/svc/ota/app/vxota` published for the first time, now packaging the vxota v0.1.1 release binary
  (checksum verified by `stage.sh`): `ghcr.io/vxedge/parts/svc/ota/app/vxota:0.1.1`,
  `sha256:38dc26f33a08dc0af3085e86caa07eb697559200d52c12e3730a7cd2e78e213d`.
- `parts/svc/ota/config/gate-store`: the OTA artifact store of the reference vehicles and the vxAPI gate,
  one 1 MiB test artifact with its signed metadata (the signing key is not published). Published as
  `ghcr.io/vxedge/parts/svc/ota/config/gate-store:0.1.0`,
  `sha256:8ea595fe8642bfba6809320befd7e9373c6eaba9f72e0ddaf3ae54da90180546`. A vehicle pins it as
  `config.artifacts` once vxedge resolves a published store.
- `parts/zone/aaos/stack/cuttlefish-auto`: an Android Automotive 26Q2 zone guest, recipe-only. It fetches
  AOSP's Cuttlefish build `16644040` (`aosp_cf_x86_64_auto-userdebug`), verifies it against `SHA256SUMS`, and
  installs vxvhal as the host Vehicle HAL server. Not republished; not yet a vxedge zone backend.
- `parts/zone/wasm/app/reflector-capsule`: the first WebAssembly capsule, a UDP reflector for
  `backend: wasm-capsule` zone nodes, with a new `wasm` zone subtype. Published as
  `ghcr.io/vxedge/parts/zone/wasm/app/reflector-capsule:0.1.0`,
  `sha256:4392871714b302e17dc9f81518d4768093bbfbddac6dbc9c10a517a9f286654d`.
- `scripts/publish/publish-wasm.sh`: publishes a capsule with a pull round-trip check.
- `parts/hpc/ad/config/autoware-params`, `parts/hpc/ad/stack/autoware` and the composite
  `parts/hpc/ad/stack/ad-baseline`, published with constituents first. The composite has not been run
  against a CARLA server.
- `parts/veh/car/config/reference-sedan-6zone`, published at `0.1.0`
  (`sha256:1bf1f9c7…89af13`), the six-zone reference vehicle, run live through `vxedge vehicle up`.
- `parts/zone/zephyr/stack/probe-bundle`: a Zephyr v4.5.0 probe guest for qemu-microvm (board
  `qemu_x86`, no MMU), reproducible in a digest-pinned container. Published as
  `ghcr.io/vxedge/parts/zone/zephyr/stack/probe-bundle:0.1.0`,
  `sha256:a50f0cb58ed9b041217cc9cdaba7555089d6c73545fcdebe90ecba250fdfe135`. A probe, not an ECU application.

### Changed

- `zone/wasm/app/reflector-capsule` is a public package. The others stay private until their licence
  terms for binary distribution are settled.

## [0.1.0] - 2026-10-29

First public release: recipes, descriptors and publish scripts.

### Added

- `gw/nos/os/sonic-vs`, the SONiC-VS network OS part (2026-08-03), published as
  `ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:202505.1182664`. The image is fetched from the
  upstream Azure Pipelines build 1182664 (branch `202505`) and republished as a single-disk ORAS
  artifact with `scripts/publish/publish-vm-disk.sh`. The pushed layer digest, size and
  `org.vxedge.*` annotations were confirmed against `bundle/meta.json`. Private package. A
  disposable copy booted, and `verify-config-parity.py` loaded the rendered `config_db.json`
  with SONiC's own `config load` and read all four declared fields back unchanged. The image
  bundles third-party licence terms, recorded in `part.yaml` rather than asserted as one SPDX
  identifier.
- Open-source release preparation: `LICENSE` (Apache-2.0), `NOTICE`, rewritten `README.md`.


- Repo scaffolding: `README.md`, `AGENTS.md`, `TASKS.md`, `parts/{zone,hpc,gw,agent,svc}/` +
  `scripts/publish/` directory layout.

- Second part published to GHCR (2026-07-28), and the first container one:
  `ghcr.io/vxedge/parts/hpc/ad/middleware/ros2-humble:0.1.0`,
  `sha256:63d1fc55b689c82420c51217b7915438dc9495656de135069e96ad72bb5d75df`. Private package;
  8 `org.vxedge.*` labels intact. Both publish paths (ORAS artifact and OCI container) are
  now proven against a real registry. `carla-ros-bridge` is pinned to this digest, and a build
  confirmed it resolves the dependency from the registry rather than a local tag.
- `publish-container.sh` reports the pushed manifest digest (`podman push --digestfile`),
  which is the value a dependent part or experiment manifest pins. Reading it back off the
  registry would need a pull token, needless for a private package when the push already
  knows the answer.
- **`schema/taxonomy.yaml`**: classes, subtypes, layers, supplier code and digest width
  extracted out of `vxpn.py` into a single reviewable data file. The script now holds the
  algorithm only. Subtypes became class-scoped in the move, so `hpc/zephyr` is rejected rather
  than silently encoded; `format.name_digest_chars` became a knob rather than a constant.
  Verified: every existing part number is byte-identical after the refactor.
- **`part.yaml` per part**: licence, upstream pin, GPU need, SBOM slot, free-form
  annotations. Replaces scraping `# license:` comments out of Containerfiles. Identity
  (class/subtype/layer/name) is deliberately *not* restatable there; `vxpn.py meta` rejects a
  declaration that tries, since that duplication is what the no-catalog rule exists to stop.
- `vxpn.py meta` (the single resolver every publish script and build recipe now goes through)
  and `vxpn.py lint` (validates each part against the `build:` contract its layer declares).
- Upstream pins moved from Containerfiles into `part.yaml`; the publish script injects them
  as `--build-arg UPSTREAM=<ref>@<digest>`, so recipes carry no version data at all.
- `scripts/sbom.sh`: CycloneDX generation, deliberately non-blocking: no tooling installed
  means no SBOM, a clear message, and exit 0. `org.vxedge.sbom` is emitted only when the file
  really exists, so a missing SBOM can never become a false claim.
- Subtypes for all five classes (2026-07-28). `agent` and `svc` previously had none, so
  `vxprobe`, `vxtraffic`, the `vxota` crates and the `vxtelemetry` crates, all shipped code,
  could not be numbered; nor could Open5GS/UERANSIM, the components behind the H2 result.
  Added `agent`→`probe`/`load`/`collect`, `svc`→`ota`/`telemetry`/`observability`/`signal`,
  `gw`→`5gc`/`ran`/`dp`, `zone`→`mcu`. Existing part numbers are unaffected.
- `scripts/publish/publish-container.sh` and `scripts/publish/publish-files.sh`: the
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
- `parts/zone/linux/stack/probe-bundle/build.sh`: the `linux-probe` guest bundle recipe,
  copied from `zones-legacy/scripts/build-guest-bundle.sh` and adapted to stamp `org.vxedge.*`
  classification fields into `meta.json`. Verified end to end: the bundle boots under
  `qemu-microvm` when pulled fresh from a registry.

### Changed

- **`carla-ros-bridge` retired, replaced by `carla-client`** (2026-07-28), published as
  `ghcr.io/vxedge/parts/hpc/ad/middleware/carla-client:0.1.0`,
  `sha256:832dedf3...`. Building the original part is what surfaced the problem:
  `carla-simulator/ros-bridge` master has been frozen since 2022-07-22 and requires CARLA
  0.9.13, while the `carla-server` part is pinned to 0.9.15. It built and imported cleanly, which
  is what made it dangerous: a version-mismatched bridge still produces numbers. The
  supported path is `autoware_carla_interface`, which ships inside `autoware_universe` and
  documents exactly 22.04/humble/0.9.15; this part supplies the matching CARLA client.
  The part's VXPN changed with its name: `VXEUS-HADS-M7BO` → `VXECL-HADS-M70H`.

### Fixed

- Initramfs builds are now byte-reproducible. The inherited recipe produced a different
  `initrd.img` sha256 on every run (cpio embeds per-file mtimes; gzip embeds a build
  timestamp), so recorded digests identified a build rather than its inputs, at odds with
  the digest-based reproducibility rule these parts depend on. Now pins mtimes via
  `SOURCE_DATE_EPOCH`, sorts cpio member order, and passes `cpio --reproducible` / `gzip -n`.
  **The same bug remains live in `zones-legacy/scripts/build-guest-bundle.sh`.**
- `build.sh` honours the `KERNEL=` override its own usage comment documented but the
  inherited code ignored (plus a matching `KVER=`, so an overridden kernel can't be
  mislabelled in `meta.json`).
- `scripts/publish/publish-vm-bundle.sh`: ORAS push/pull-verify wrapper for `zone`-class
  bundles: derives manifest annotations from whatever `org.vxedge.*` keys the bundle's
  `meta.json` declares, sets `artifactType: application/vnd.vxedge.part.v1`, and verifies
  the pull round-trip is byte-identical. Validated against a local `registry:2`.

### Known gaps

- Published parts under `ghcr.io/vxedge/parts/` are private for now. The recipes in this
  repository build the same parts locally, and `./scripts/vxpn.py lint` runs without a registry.
- The probe bundle has so far been built only with a stand-in kernel, because
  `/boot/vmlinuz-*` is root-only `0600` on common distributions. Everything else in the
  pipeline is verified.
- `zones-legacy`, the archived predecessor of the zone recipes, is not public.
