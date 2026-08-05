# parts/gw/ran/os/ueransim

UERANSIM RAN simulator (gNB + UE), the sibling of `gw/5gc/os/open5gs` — together these carry
H2's real numbers (`docs/TASKS.md` priority-1 buildout item, 2026-08-05). Same content as
`vxedge/containers/fiveg/Containerfile.ueransim`, re-homed under `vxparts`.

Classification: `class=gw`, `subtype=ran`, `layer=os`.

## Cross-repo build dependency — run `./stage-vxprobe.sh` first

This image bundles a prebuilt `vxprobe` binary (from the separate `vxagents` repo) so an H2
campaign's reflector can run *inside* a UE's own pod/netns — the same way H1's methodology runs
the reflector on the ADAS zone node itself, not pinged from outside. `podman build`'s context is
sandboxed to this directory, so it can't reach `vxagents` directly. The staging step is
deliberately not named `build.sh`: `vxpn.py lint` treats `Containerfile`/`build.sh` as mutually
exclusive build recipes, and this is a prebuild helper for the `Containerfile` recipe, not a
competing recipe of its own.

```
./stage-vxprobe.sh                                            # stages bin/vxprobe.bin
../../../../../scripts/publish/publish-container.sh gw/ran/os/ueransim 0.1.0
```

`bin/` is gitignored repo-wide (`vxparts/.gitignore: parts/**/bin/`) — nothing to clean up
manually, and nothing staged there is committed.

## Upstream pin

Same base-image pattern as `gw/5gc/os/open5gs`: `upstream.ref`/`digest` in `part.yaml` pin the
`FROM` base both build stages share (`docker.io/library/ubuntu:24.04`, resolved 2026-08-05).
UERANSIM itself is a source build, pinned by git tag **`v3.2.7`**, resolved 2026-08-05 to its
actual commit object (`gh api repos/aligungr/UERANSIM/git/refs/tags/v3.2.7`) —
`1d1e154f869260b5e98f6905827b1bd9b8663afc` — recorded in `annotations.ueransim-commit` since
it isn't an OCI digest and doesn't belong in the `upstream` field's sha256 slot.

## License

**AGPL-3.0** (confirmed via the upstream `aligungr/UERANSIM` repo's own SPDX metadata,
2026-08-05) — flagged by `docs/TASKS.md`'s workspace-licensing-review item alongside Open5GS,
same caveat: standalone containerized service, not linked into vxedge code, final
redistribution-terms call belongs to whoever owns that review.

## Host prerequisites (unchanged from `vxedge/containers/fiveg`)

- `modprobe sctp` once per boot on the host — UERANSIM's NGAP uses kernel SCTP, which is not
  namespaced; nothing else from UERANSIM touches the host.
- UE containers need `--cap-add=NET_ADMIN --device /dev/net/tun` (creates `uesimtunN`).

## Verified 2026-08-05

`./stage-vxprobe.sh` staged `bin/vxprobe.bin` from the sibling `vxagents` repo, then
`VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/gw/ran/os/ueransim 0.1.0` built
clean (two-stage build: compiles `nr-gnb`/`nr-ue`/`nr-cli` from the pinned git tag, then a
minimal runtime image); all 11 `org.vxedge.*` labels confirmed intact. Ran the built image
with no arguments and confirmed both `nr-gnb --version`/`nr-ue --version` report `v3.2.7`,
matching the pinned tag exactly. `vxpn.py lint`/`scan` both pass with no collisions. Not yet
re-verified against a live pod run with this image swapped in for `vx5g-ran` — that repoint is
a deliberate, separate follow-up, same reasoning as `gw/5gc/os/open5gs`'s README.
