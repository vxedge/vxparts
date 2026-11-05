# zone/zephyr/stack/probe-bundle

A Zephyr RTOS image that plays the same role as the Linux `probe-bundle` for a vxedge
zone ECU: it comes up on a virtio-net NIC, takes its address from the boot command line,
and answers the vxedge flow probes. It is a probe guest, not an ECU application.

## What it is

- Zephyr v4.5.0, SDK 1.0.1, board `qemu_x86` (32-bit, single Multiboot ELF), built in a CI
  container pinned by digest. `build.sh` documents the pin.
- Backend: `qemu-microvm` only. Cloud Hypervisor and containers are not supported.
- Network: the application reads the MAC from the virtio-net device config and sets it as
  the link address, then takes `vx.ip=<cidr>` and `vx.node=<id>` from the Multiboot
  command line that vxedge passes.
- Bundle layout follows the vm-bundle contract: `vmlinuz` (the Zephyr ELF), `initrd.img`
  (an empty stub, the contract requires the slot), `meta.json`.

## What it is not

- Not a safety-certified or production image.
- Runs without an MMU (`CONFIG_X86_MMU=n`): 32-bit PAE page tables triple-fault under KVM
  on microvm, so the image uses a flat address space.
- Not run on real hardware, and not run on any backend other than qemu-microvm.
- `qemu_x86_64` is not usable: it needs a two-image locore/main load that the bundle
  contract does not carry.

## Reproducibility

Two builds in the pinned container produce the same `vmlinuz` sha256. The published
digest is recorded in the vxparts changelog and FACTS.

## Build

```
./build.sh <out-dir>
```
