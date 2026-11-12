# zone/freertos/stack/probe-bundle

A FreeRTOS image that plays the same role as the Linux and Zephyr `probe-bundle`s for a vxedge zone ECU. It
comes up on a virtio-net NIC, takes its address from the boot command line, and answers the vxedge flow
probes. It is a probe guest, not an ECU application.

## What it is

- **Software:** FreeRTOS-Kernel V11.2.0 on its `IA32_flat` port, with FreeRTOS-Plus-TCP V4.4.2 (IPv4, UDP, ARP
  and ICMP echo), both MIT. It is a 32-bit Multiboot ELF of about 60 KB.
- **Network:** `app/virtio_net.c` is a FreeRTOS-Plus-TCP network interface for virtio-net over the virtio-mmio
  version 2 (modern) transport. It negotiates `VIRTIO_F_VERSION_1` and `VIRTIO_NET_F_MAC` and uses one
  receive and one transmit queue.
- **Address:** the application takes `vx.ip=<cidr>` and `vx.node=<id>` from the Multiboot command line vxedge
  passes, and the MAC from the virtio device configuration, so vxedge's per-node MAC reaches the wire.
- **Payload:** `app/main.c` echoes every datagram on UDP :9800, as `vxprobe reflect` does, and prints
  `vxparts guest up: node=<id>, starting reflector :9800` to the console.
- **Bundle layout:** follows the vm-bundle contract: `vmlinuz` (the ELF), `initrd.img` (empty; the contract
  names the slot) and `meta.json`.

## What it is not

- **Not ECU software:** not a safety-certified or production image.
- **Not an MCU:** it runs FreeRTOS on a 32-bit x86 microVM, and says nothing about FreeRTOS on Cortex-M or
  other MCU silicon.
- **No interrupts for the NIC:** the driver polls its receive ring every tick (1 ms), so a reply can wait up
  to a tick. The scheduler tick is the local APIC timer. Critical sections mask interrupts (`cli`).
- **Flat addressing:** no MMU, and one core.
- **One backend:** `qemu-microvm` only; Cloud Hypervisor, libvirt and containers are not supported.
- **Never timed:** a probe guest's latency includes the polling interval.

## Verified

- **Probes:** under `qemu-system-x86_64 -M microvm,acpi=off -enable-kvm` with the modern virtio-mmio
  transport, as vxedge's `qemu-microvm` backend starts it, the published `agent/probe/app/vxprobe` 0.2.0 sent
  20 probes to the guest over QEMU user networking and got 20 replies.
- **Reproducible:** two builds give the same `vmlinuz`
  (`9e0435d765f3eca921d691d48596bc3a6220b4d20689360790485f527831d5b4`).

## Build

```
./build.sh <out-dir>
```

Needs only Podman. The build runs in `debian:bookworm-slim` pinned by digest. Its compiler comes from
`snapshot.debian.org` at a fixed date (gcc 12.2.0, binutils 2.40). FreeRTOS-Kernel and FreeRTOS-Plus-TCP are
cloned at their pinned commits, and the build refuses any other commit. `meta.json` records all of these.

## Published

`ghcr.io/vxedge/parts/zone/freertos/stack/probe-bundle:0.1.1`, `sha256:5c1a314c658c2e1ebdb71761c1d0aecdb2d8ae0ae792840b77964c7ec0fa6e0d`. 0.1.1 is 0.1.0's payload byte for byte, with `org.vxedge.reflector: udp/9800` declared.

## Publish

```
../../../../../scripts/publish/publish-vm-bundle.sh <out-dir> ghcr.io/vxedge/parts/zone/freertos/stack/probe-bundle:0.1.0
```
