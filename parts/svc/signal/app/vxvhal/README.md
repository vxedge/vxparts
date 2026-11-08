# vxvhal — `VXELD-SSIG-AIVA`

`ghcr.io/vxedge/parts/svc/signal/app/vxvhal` · Apache-2.0 · no GPU

The Vehicle HAL server of an Android Automotive zone: it serves AAOS's gRPC Vehicle HAL
(`GRPCVehicleHardware`'s `VehicleServer`, AOSP `android17-release`) from COVESA VSS signals in a Kuksa
databroker, so CarService in the guest reads the vehicle's signals over the slice (`ARCHITECTURE.md` §9).
It is the payload of the cockpit gateway node in `vx-reference-sedan-03`. It is not a vendor Vehicle HAL.

## What it packages

`vxvhal` from the [vxvhal](https://github.com/vxedge/vxvhal) v0.1.0 release (commit `c7b7352`), the static
x86_64 musl build, verified by `stage-release.sh` against the release tarball's sha256 (`part.yaml`) before
it is packaged, and the release's default mapping (`PERF_VEHICLE_SPEED`, `ENGINE_RPM`, `PERF_ODOMETER`, `GEAR_SELECTION`) at
`/etc/vxvhal/mapping.yaml`. The image is `FROM scratch`: the binary and the mapping only.

It listens on `0.0.0.0:9300` and reads the databroker at `127.0.0.1:55555`, so place the vehicle's signal
plane on the node that runs it, as a gateway ECU hosts both, or set `VXVHAL_DATABROKER`. `VXVHAL_MAPPING`
points at another mapping.

## Build and publish

```sh
./parts/svc/signal/app/vxvhal/stage-release.sh
./scripts/publish/publish-container.sh parts/svc/signal/app/vxvhal 0.1.0
```

Bump the release, commit and checksum in `part.yaml` and `stage-release.sh` together when vxvhal moves.

## Published

`0.1.0`: `sha256:313f44bd558be6783287f45fa45c2439d336951e2d65f4ca5c2df63ce6f85423`, 11 `org.vxedge.*` labels.
A vehicle pins it by that digest.
