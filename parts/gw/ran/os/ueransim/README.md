# parts/gw/ran/os/ueransim

UERANSIM RAN simulator (gNB + UE), the sibling of `gw/5gc/os/open5gs` — together these carry
H2's real numbers. Same content as
`vxedge/containers/fiveg/Containerfile.ueransim`, re-homed under `vxparts`.

Classification: `class=gw`, `subtype=ran`, `layer=os`.

## vxprobe: run `./stage-release.sh` first

The image bundles `vxprobe` so a campaign's reflector can run inside a UE's own pod and network
namespace. It is the vxagents release named in `part.yaml` (`vxagents-release`, now `v0.2.3`):
`./stage-release.sh` downloads that release's x86_64 tarball, checks it against
`vxagents-tarball-sha256` and stages the binary in `bin/`, which is gitignored. The script is
named `stage-*.sh` so CI runs it before the build, as it does for `agent/load/app/vxtraffic`.

```
./stage-release.sh
../../../../../scripts/publish/publish-container.sh gw/ran/os/ueransim 0.1.0
```

## Upstream pin

Same base-image pattern as `gw/5gc/os/open5gs`: `upstream.ref`/`digest` in `part.yaml` pin the
`FROM` base both build stages share (`docker.io/library/ubuntu:24.04`, resolved 2026-08-05).
UERANSIM itself is a source build, pinned by git tag **`v3.2.7`**, resolved 2026-08-05 to its
actual commit object (`gh api repos/aligungr/UERANSIM/git/refs/tags/v3.2.7`) —
`1d1e154f869260b5e98f6905827b1bd9b8663afc` — recorded in `annotations.ueransim-commit` since
it isn't an OCI digest and doesn't belong in the `upstream` field's sha256 slot.

## License

**AGPL-3.0** (confirmed via the upstream `aligungr/UERANSIM` repo's own SPDX metadata,
2026-08-05) — the same case as Open5GS,
same caveat: standalone containerized service, not linked into vxedge code, final
redistribution-terms call belongs to the maintainers' licensing review.

### Source offer

The published image contains UERANSIM v3.2.7, built unmodified from upstream commit
`1d1e154f869260b5e98f6905827b1bd9b8663afc` and licensed under AGPL-3.0. The Corresponding Source is
the upstream repository at that commit:
<https://github.com/aligungr/UERANSIM/tree/1d1e154f869260b5e98f6905827b1bd9b8663afc>. This
repository adds no patches to it. If you received the image and cannot obtain that source from the
link, open an issue at <https://github.com/vxedge/vxparts/issues> and the source will be provided
at no charge beyond the cost of delivery. The offer is valid for as long as the image is
distributed.

## Host prerequisites (unchanged from `vxedge/containers/fiveg`)

- `modprobe sctp` once per boot on the host — UERANSIM's NGAP uses kernel SCTP, which is not
  namespaced; nothing else from UERANSIM touches the host.
- UE containers need `--cap-add=NET_ADMIN --device /dev/net/tun` (creates `uesimtunN`).

## Published

`ghcr.io/vxedge/parts/gw/ran/os/ueransim:0.1.0`, `sha256:39393bb1982f57f4c3b14ff743baea810868b089d7ceda633b85026817fe066a`,
with UERANSIM v3.2.7 and vxprobe 0.2.3.

Verified 2026-11-13 before publishing: vxedge's `fiveg_podman` integration test, pointed at both
0.1.0 images, brought up the core and RAN pods, attached both UEs (each got a PDU-session address)
and started `vxprobe` inside each UE's pod, then tore everything down.
