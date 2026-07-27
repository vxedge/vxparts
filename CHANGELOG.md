# Changelog

All notable changes to this project will be documented in this file. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows SemVer
(`../docs/VERSIONING.md`).

## [Unreleased]

### Added

- Repo scaffolding: `README.md`, `AGENTS.md`, `TASKS.md`, `parts/{zone,hpc,gw,agent,svc}/` +
  `scripts/publish/` directory layout.
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
