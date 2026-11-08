# zone/aaos/stack/cuttlefish-auto

An Android Automotive OS 26Q2 zone guest: AOSP's own Cuttlefish auto build, pinned by build ID and checksums,
with its Vehicle HAL served from Kuksa VSS signals by vxvhal instead of AOSP's fake vehicle.

## What it is

- AAOS 26Q2: Android 17, API level 37, `ro.build.id` `CP2A.260605.016`. AOSP build `16644040` of
  `aosp_cf_x86_64_auto-userdebug` on `aosp-android-latest-release`, fetched from `ci.android.com`.
- Recipe-only. `build.sh` runs `cvd fetch`, checks every image against `SHA256SUMS`, and installs
  `vhal-proxy-vxvhal.sh` as Cuttlefish's host `vhal_proxy_server`. The guest's `GRPCVehicleHardware` then
  dials vxvhal on `192.168.98.1:9300`.
- A vxedge zone through `backend: attach` (vxedge 0.9.1 or later). This directory is also the adapter: copy
  `attach.yaml`, `start.sh`, `status.sh`, `stop.sh`, `vhal-proxy-none.sh` and `SHA256SUMS` into the vehicle as a
  local `kind: attach` part, and run `vxedged` with `VXEDGE_AAOS_HOME` set to the `build.sh` output. `start.sh`
  refuses images that do not match `SHA256SUMS`, and puts a stub in the place of Cuttlefish's host Vehicle HAL
  server, because the vehicle serves the Vehicle HAL on the slice (vxvhal on the cockpit gateway ECU). The
  device's link endpoint names `host_interface: cvd-etap-01`, and the guest sets `192.168.98.3/24` itself.
  `vx-reference-sedan-03` in vxperiments is the reference.
- A VirtIO guest: it boots under QEMU/KVM as well as Cuttlefish's crosvm, x86_64. Needs `cuttlefish-base`
  1.57.13 or later on the host for `cvd fetch` and for the TEE helper (`secure_env`).

## What it is not

- Not republished. The images come from Google's build servers; this part pins and verifies them. That keeps
  the source of every byte with AOSP, including the GPL kernel's.
- Not booted by vxedge itself. Cuttlefish's own launcher stays the guest's host stack, as a hypervisor vendor's
  board support would; vxedge adopts the guest's Ethernet tap as the zone's slice port and gives it back at
  `down`.
- The guest needs Cuttlefish's host stack to boot, not only its TEE simulator: booted by plain QEMU it also
  needs the display, sensor and input helpers, and more. A spike on 2026-11-07 rebuilt four of them one at a time
  before concluding so.
- Not a vendor build: `userdebug`, AOSP's fake hardware for everything except the Vehicle HAL.

## Verified

On 2026-11-06, with `cuttlefish-base` 1.57.13 on x86_64: the guest booted, and CarService read
`PERF_VEHICLE_SPEED` and `ENGINE_RPM` published to a Kuksa databroker, both on request and over the property
stream (vxvhal `docs/aaos-cuttlefish.md`).

On 2026-11-08, as the attach zone `ivi-aaos` of `vx-reference-sedan-03` with vxedge 0.9.1: 10 of 10 vxAPI gate
runs, with CarService reading the vehicle's speed and gear from vxvhal across the slice in every run
(vxperiments `results/aaos-gate-2026-11-08`).

## Reproducibility

`SHA256SUMS` pins the files `cvd fetch` writes for this build. `vbmeta.img`, `vbmeta_system.img`,
`vbmeta_system_dlkm.img` and `vbmeta_vendor_dlkm.img` are not pinned: Cuttlefish's `assemble_cvd` rewrites them
at every launch.

## Host notes

- One instance per host: the adapter uses Cuttlefish's first Ethernet tap (`cvd-etap-01`), and the guest
  dials port 9300.

- `vhal-proxy-vxvhal.sh` needs `VXVHAL_BIN`, `VXVHAL_DATABROKER` and `VXVHAL_MAPPING` in the environment of
  `launch_cvd`, and the launch flag `--enable_vhal_proxy_server=true`.
- On hosts that restrict unprivileged user namespaces with AppArmor (Ubuntu 24.04 and later), crosvm's sandbox
  needs an AppArmor profile granting `userns` to `/usr/lib/cuttlefish-common/bin/crosvm`.

## Build

```
./build.sh <out-dir>
```
