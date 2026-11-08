# zone/aaos/stack/cuttlefish-auto

An Android Automotive OS 26Q2 zone guest: AOSP's own Cuttlefish auto build, pinned by build ID and checksums,
with its Vehicle HAL served from Kuksa VSS signals by vxvhal instead of AOSP's fake vehicle.

## What it is

- AAOS 26Q2: Android 17, API level 37, `ro.build.id` `CP2A.260605.016`. AOSP build `16644040` of
  `aosp_cf_x86_64_auto-userdebug` on `aosp-android-latest-release`, fetched from `ci.android.com`.
- Recipe-only. `build.sh` runs `cvd fetch`, checks every image against `SHA256SUMS`, and installs
  `vhal-proxy-vxvhal.sh` as Cuttlefish's host `vhal_proxy_server`. The guest's `GRPCVehicleHardware` then
  dials vxvhal on `192.168.98.1:9300`.
- A VirtIO guest: it boots under QEMU/KVM as well as Cuttlefish's crosvm, x86_64. Needs `cuttlefish-base`
  1.57.13 or later on the host for `cvd fetch` and for the TEE helper (`secure_env`).

## What it is not

- Not republished. The images come from Google's build servers; this part pins and verifies them. That keeps
  the source of every byte with AOSP, including the GPL kernel's.
- Not yet a vxedge zone. The plan is vxedge's generic `attach` backend: Cuttlefish's own launcher stays the
  guest's host stack, as a hypervisor vendor's board support would, and vxedge adopts the guest's Ethernet tap as
  the zone's slice port and serves its Vehicle HAL from the vehicle. Until then the guest is launched with
  `launch_cvd` beside a vehicle, on Cuttlefish's own bridge.
- The guest needs Cuttlefish's host stack to boot, not only its TEE simulator: booted by plain QEMU it also
  needs the display, sensor and input helpers, and more. A spike on 2026-11-07 rebuilt four of them one at a time
  before concluding so.

## Verified

On 2026-11-06, with `cuttlefish-base` 1.57.13 on x86_64: the guest booted, and CarService read
`PERF_VEHICLE_SPEED` and `ENGINE_RPM` published to a Kuksa databroker, both on request and over the property
stream (vxvhal `docs/aaos-cuttlefish.md`).

## Reproducibility

`SHA256SUMS` pins the files `cvd fetch` writes for this build. `vbmeta.img`, `vbmeta_system.img`,
`vbmeta_system_dlkm.img` and `vbmeta_vendor_dlkm.img` are not pinned: Cuttlefish's `assemble_cvd` rewrites them
at every launch.

## Host notes

- `vhal-proxy-vxvhal.sh` needs `VXVHAL_BIN`, `VXVHAL_DATABROKER` and `VXVHAL_MAPPING` in the environment of
  `launch_cvd`, and the launch flag `--enable_vhal_proxy_server=true`.
- On hosts that restrict unprivileged user namespaces with AppArmor (Ubuntu 24.04 and later), crosvm's sandbox
  needs an AppArmor profile granting `userns` to `/usr/lib/cuttlefish-common/bin/crosvm`.

## Build

```
./build.sh <out-dir>
```
