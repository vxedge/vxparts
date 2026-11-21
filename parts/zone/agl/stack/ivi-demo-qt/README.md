# zone/agl/stack/ivi-demo-qt — `VXEC4-ZAGL-STMP`

An Automotive Grade Linux zone guest for arm64: AGL's own Vimba 22.0.1 build of the Qt IVI demo for
`qemuarm64`, pinned by checksum and booted by vxedge from its root disk.

## What it is

- AGL 22.0.1 (Vimba), image `agl-ivi-demo-qt`, machine `qemuarm64`, built by AGL on 2026-10-28. Linux 6.18.52.
  It includes AGL's compositor and Qt home screen, and a Kuksa databroker with its client.
- Recipe-only. `build.sh` fetches the kernel and the compressed ext4 root filesystem from AGL's release server
  by their timestamped names, checks both against `SHA256SUMS`, and lays out a bundle:
  - `vmlinuz`: AGL's kernel `Image`, unchanged;
  - `rootfs.img`: AGL's ext4 image, decompressed and unchanged (its sha256 is pinned too);
  - `meta.json`: `aarch64`, 4 CPUs and 2 GiB, AGL's own QEMU settings.
- AGL publishes no checksums beside these images. `SHA256SUMS` pins the files as downloaded from AGL's release
  server on 2026-11-21.
- A vxedge zone through `backend: qemu-microvm`, which boots a bundle's root disk as `/dev/vda` from a snapshot and
  sets the guest's address with the kernel's `ip=` (ARCHITECTURE.md §9). The image is never written: every boot
  starts from AGL's image.

## What it is not

- Not republished. The images come from AGL's release server; this part pins and verifies them. That keeps the
  source of every byte with AGL, including the GPL kernel's: AGL publishes the sources and licence files beside
  the build, under `deploy/sources` and `deploy/licenses`.
- Not timed. On a host of another instruction set it runs under emulation (TCG), which is functional evidence only.
- Headless: the compositor runs with no display attached, and no input reaches the home screen.
- Not wired to the vehicle's signals yet: its Kuksa databroker serves only the guest itself.

## Licences

The image bundles AGL's packages under their own terms: Apache-2.0 for AGL's applications, GPL-2.0 for the kernel,
LGPL-3.0 for Qt, and others per package, as AGL's licence manifest lists. `part.yaml` names the main ones.

## Build

```
./build.sh [out-dir]
```

Needs `curl`, `xz` and `sha256sum`. Downloads about 750 MB and writes a bundle of about 5.8 GB.
