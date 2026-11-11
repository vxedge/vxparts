# zone/zephyr/firmware/probe-mps2

Zephyr firmware for a microcontroller zone node: QEMU's `mps2-an385` board (Cortex-M3) with its LAN9118 NIC,
booted by vxedge's `qemu-mcu` backend. It takes its address from the semihosting command line and answers the
vxedge flow probes. It is a probe guest, not an ECU application.

## What it is

- **Software:** Zephyr v4.5.0, board `mps2/an385`, with Zephyr's `smsc911x` Ethernet driver and its socket
  API. Apache-2.0.
- **Address:** `vx.ip=<cidr>` and `vx.node=<id>` come from the semihosting command line (`SYS_GET_CMDLINE`),
  which is how `qemu-mcu` passes them. The driver takes the MAC QEMU gave the NIC, so vxedge's per-node MAC
  reaches the wire.
- **Payload:** `app/src/main.c` echoes every datagram on UDP :9800, as `vxprobe reflect` does. The first UART
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
  (62, 63, 64 and 66 bytes) and got 80 of 80 replies.
- **Address and MAC:** the console printed the `vx.ip` and `vx.node` it was given and the MAC set on the NIC.
- **Reproducible:** two builds give the same `firmware.elf`
  (`5ae72db3626dd26992119bd1540ca51e68052ed741424b902f84f29dd4f772b1`) and the same `meta.json`.

## Build

```
./build.sh <out-dir>
```

Needs only Podman. The build runs in `debian:trixie` pinned by digest, with the Arm GNU toolchain and Zephyr's
host tools from `snapshot.debian.org` at a fixed date. It uses no west: Zephyr and the two modules a Cortex-M3
build needs (`cmsis`, `cmsis_6`) are cloned at the commits Zephyr v4.5.0's `west.yml` pins, and the build
refuses any other commit. `meta.json` records all of these and the toolchain.

## Publish

```
../../../../../scripts/publish/publish-firmware.sh <out-dir> ghcr.io/vxedge/parts/zone/zephyr/firmware/probe-mps2:0.1.0
```
