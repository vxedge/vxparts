# reference-sedan-6zone — `VXEFJ-VCAR-C2K3`

`ghcr.io/vxedge/parts/veh/car/config/reference-sedan-6zone` · config layer · ORAS artifact

A reusable **vehicle structural model** (`kind: vehicle` per `docs/ARCHITECTURE.md` §6.0.1:
`zones`/`devices`/`functions`/`links`/`channels`) covering all six canonical zone roles
(`front-left`, `front-right`, `rear-left`, `rear-right`, `central-hpc`, `gateway` — the fixed
vocabulary from ARCHITECTURE.md §3). Published here so an experiment workspace can pull one
digest-addressed structural model instead of hand-copying a `vehicle.yaml` — the same
motivation as `hpc/ad/config/autoware-params`: an unversioned or divergently-copied structural
file is a reproducibility gap, not a convenience shortcut.

This part is the `veh` class's first instance (Track D consequence a):
vehicle models are `config`-layer parts, numbered by the same VXPN scheme as every other part
— no separate model-number scheme, so sharing a vehicle stays a single `oras pull`.

## What this is

`vehicle.yaml` is the six-zone reference vehicle of `PROVISIONING.md` §4 (`vx-reference-sedan-01`):
`front-left`, `front-right`, `rear-left`, `rear-right` and `central-hpc`, with an ECU plus a sensor
or actuator in the corner zones, central compute, an OTA service and the Kuksa signal plane. There
is no `gateway` zone entry, because the gateway is provisioned from the experiment's network, as in
every other vehicle document.

**Validated on probe guests.** All six zone devices boot `zone/linux/stack/probe-bundle:0.1.0`
(`sha256:33c9c8d8625bd5c6d1f4d3d0c561fdaa930e057fcd1fb24fb3badb402f25429d`). The roles are
structural claims, and the RTOS images they imply replace the probe one zone at a time. It was
brought up, probed, brought up a second time, restarted and torn down with `vxedge vehicle`; the
evidence is `vxperiments` `results/reference-vehicle-2026-11-04`. It is a provisioning result, not
a measurement. The baseline that picks the guests (`parts.yaml`) lives with the vehicle in
`vxperiments`, because its probe image is local to a host.

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```
