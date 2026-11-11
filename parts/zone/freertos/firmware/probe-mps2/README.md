# zone/freertos/firmware/probe-mps2

FreeRTOS firmware for a microcontroller zone node: QEMU's `mps2-an385` board (Cortex-M3) with its LAN9118
NIC, booted by vxedge's `qemu-mcu` backend. It takes its address from the semihosting command line and
answers the vxedge flow probes. It is a probe guest, not an ECU application.

## What it is

- **Software:** FreeRTOS-Kernel V11.2.0 on its `ARM_CM3` port, with FreeRTOS-Plus-TCP V4.4.2 (IPv4, UDP, ARP
  and ICMP echo) and its `MPS2_AN385` network interface. All MIT.
- **Board support:** the startup code, newlib stubs, linker script and CMSIS headers come from FreeRTOS's own
  `FreeRTOS_Plus_TCP_Echo_Qemu_mps2` demo (FreeRTOS 202411.00), fetched at a pinned commit, not copied here.
- **Driver fix:** `patches/lan9118-rx-tail.patch` changes the port's RX FIFO read. Without it, the driver
  reads one word too many after a frame whose length is a multiple of 4, and the NIC stops receiving.
- **Address:** `vx.ip=<cidr>` and `vx.node=<id>` come from the semihosting command line (`SYS_GET_CMDLINE`),
  which is how `qemu-mcu` passes them. The MAC is the one QEMU gave the NIC, so vxedge's per-node MAC reaches
  the wire.
- **Payload:** `app/main.c` echoes every datagram on UDP :9800, as `vxprobe reflect` does. The first UART
  prints the command line, the MAC, and `vxparts guest up: node=<id>, starting reflector :9800`.
- **Bundle layout:** `firmware.elf` and `meta.json`. `meta.json` names the board (`org.vxedge.machine:
  mps2-an385`) and the arch (`org.vxedge.arch: armv7m`), which `qemu-mcu` checks before it boots.

## What it is not

- **Not ECU software:** not a safety-certified or production image.
- **Never timed:** `qemu-mcu` runs it under TCG, so its results are functional evidence only.
- **Not run on silicon:** only on QEMU's `mps2-an385` model.
- **Needs semihosting:** without the semihosting command line it prints its boot line and stops.

## Verified

- **Probes:** under `qemu-system-arm -M mps2-an385` with QEMU user networking and the semihosting command line
  `qemu-mcu` passes, the published `agent/probe/app/vxprobe` 0.2.0 sent 20 probes at each of four payload sizes
  (62, 63, 64 and 66 bytes) and got 80 of 80 replies. The 62-byte payload gives a frame whose length is a
  multiple of 4, the case the driver fix covers.
- **Address and MAC:** the console printed the `vx.ip` and `vx.node` it was given and the MAC set on the NIC.
- **Reproducible:** two builds give the same `firmware.elf`
  (`bcc30cfc4ff2e36312544e4ff9bec8600a30a2f583fa0edecfe41ae84bed64b0`) and the same `meta.json`.

## Build

```
./build.sh <out-dir>
```

Needs only Podman. The build runs in `debian:bookworm-slim` pinned by digest. Its compiler comes from
`snapshot.debian.org` at a fixed date. FreeRTOS-Kernel and FreeRTOS-Plus-TCP are cloned at their pinned commits,
and the build refuses any other commit. The demo's 11 board files are fetched at a pinned commit of the `FreeRTOS`
repository and checked against `demo.sha256`. `meta.json` records all of these, the patch's sha256 and the
toolchain.

## Publish

```
../../../../../scripts/publish/publish-firmware.sh <out-dir> ghcr.io/vxedge/parts/zone/freertos/firmware/probe-mps2:0.1.0
```
