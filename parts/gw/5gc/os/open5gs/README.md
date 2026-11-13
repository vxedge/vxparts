# parts/gw/5gc/os/open5gs

The Open5GS 5G core. This part carries the same content as
`vxedge/containers/fiveg/Containerfile.open5gs`, re-homed under
`vxparts`' class/subtype/layer structure so it's a real, publishable, digest-pinned loadable
instead of a bare `podman build` step inside the `vxedge` repo.

Classification: `class=gw`, `subtype=5gc`, `layer=os` (taxonomy's own description of `os`:
"guest operating system **or base container image**" — this is the container case, same as
`gw/nos/os/sonic-vs`).

## Not a relabeled upstream image

Unlike `hpc/ad/middleware/ros2-humble` (a thin relabel of an official OCI image), Open5GS has
no official container image this project validated against — it installs via the
`ppa:open5gs/latest` Ubuntu PPA, confirmed 2026-08-05 (same non-OCI-upstream honesty
`gw/nos/os/sonic-vs`'s README already applies to its own Azure-Pipelines source). `upstream.ref`/
`digest` in `part.yaml` pin the actual `FROM` base
(`docker.io/library/ubuntu:24.04@sha256:561618e2...`, resolved 2026-08-05) — the value
`publish-container.sh`'s `--build-arg UPSTREAM=<ref>@<digest>` mechanism injects. The Open5GS
package version target (`2.8.0`, matching what `vxedge-core::fiveg`'s renderer is validated
against — `crates/vxedge-core/src/fiveg/mod.rs:9`) lives in `annotations.open5gs-version`, not
in `upstream`, because a PPA install isn't byte-reproducible the way a digest-pinned image pull
is: apt always resolves "whatever's current in the PPA today." That's a real, known limitation,
not glossed over — re-pin `open5gs-version` deliberately (and note in this file) if a PPA
update is ever suspected of changing NF behavior underneath a frozen experiment result.

## License

**AGPL-3.0** (confirmed via the upstream `open5gs/open5gs` repo's own SPDX metadata,
2026-08-05). It is one of the two AGPL parts here, with `gw/ran/os/ueransim`, whose linking
and service terms need care. This part runs Open5GS as a standalone containerized service (no vxedge code links against it), the
normal AGPL network-service deployment shape — but the final call on redistribution terms for
a *built* image belongs to the maintainers' licensing review and is not settled here.

### Source offer

The published image contains Open5GS 2.8.0, installed unmodified from the `ppa:open5gs/latest`
packages and licensed under AGPL-3.0. The Corresponding Source is the upstream repository at the
`v2.8.0` tag: <https://github.com/open5gs/open5gs/tree/v2.8.0>. This repository adds no patches
to it. If you received the image and cannot obtain that source from the link, open an issue at
<https://github.com/vxedge/vxparts/issues> and the source will be provided at no charge beyond
the cost of delivery. The offer is valid for as long as the image is distributed.

## Build

```
../../../../../scripts/publish/publish-container.sh gw/5gc/os/open5gs 0.1.0
# or, for a local build without publishing:
VXPARTS_NO_PUSH=1 ../../../../../scripts/publish/publish-container.sh gw/5gc/os/open5gs 0.1.0
```

## Published

`ghcr.io/vxedge/parts/gw/5gc/os/open5gs:0.1.0`, `sha256:dfad2271a85c7147669ed5a98cc4c61b113a915d95050ddbcfe25bdea55ac97d`,
with Open5GS `2.8.0~noble5` from the PPA and mongosh 2.14.2.

Verified 2026-11-13 before publishing: vxedge's `fiveg_podman` integration test, pointed at both
0.1.0 images, brought up the core and RAN pods, attached both UEs (each got a PDU-session address)
and started `vxprobe` inside each UE's pod, then tore everything down.
