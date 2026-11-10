# hpc/cockpit/app/qt-cluster

A Qt Quick (QML) instrument cluster on the vehicle's Kuksa signal plane. It subscribes over `kuksa.val.v2` to
three VSS signals and shows them. It renders offscreen with Qt Quick's software backend, so it needs no GPU or
display.

| Signal | Shown as |
|---|---|
| `Vehicle.Speed` | km/h |
| `Vehicle.Powertrain.Transmission.CurrentGear` | `N`, `R` or `D<n>` |
| `Vehicle.Powertrain.TractionBattery.StateOfCharge.Current` | %, red below 20 |

An HTTP endpoint on `:8080` shows that it runs:

- `GET /state.json`: the values as QML holds them (`speed`, `soc`, `gear`), and `connected`, whether the
  subscription is live.
- `GET /screenshot.png`: the cluster as rendered now, 800×300.

## What it is

- `app/cluster.py` and `app/Cluster.qml`, this part's own source. They use PySide6 6.10.1 (Qt 6.10, LGPL-3.0)
  and kuksa-client 0.6.0's generated `kuksa.val.v2` stubs.
- On `python:3.12-slim`, pinned by digest. Every Python package is pinned by hash in `requirements.txt`
  (`uv pip compile --generate-hashes requirements.in`). Qt's runtime libraries come from the base's own Debian
  release.
- Runs as an unprivileged user. It exits on SIGTERM, which it handles itself as PID 1.

## Configuration

| Variable | Default | |
|---|---|---|
| `CLUSTER_DATABROKER` | `127.0.0.1:55555` | the databroker, by default on the same device |
| `CLUSTER_LISTEN` | `0.0.0.0:8080` | the HTTP endpoint |

A vehicle runs it as the payload of the device the signal plane is placed on, so the databroker is on
`127.0.0.1`, as `svc/signal/app/vxvhal` does:

```yaml
devices:
  ivi1: { role: ecu, zone: cabin, backend: container }
signal_plane:
  kuksa:
    image: { url: ghcr.io/eclipse-kuksa/kuksa-databroker@sha256:529d8c6d3cc223362667672978bcb8f92c4d356b25aedd336e7a2e004d7279bd, kind: container }
    on: ivi1
    config: { listen: "0.0.0.0:55555" }
```

with the part as `ivi1`'s payload in `parts.yaml`.

## Verified

Run locally under rootless Podman, beside `kuksa-databroker` 0.7.1:

- It renders and reports `connected: false` until the databroker is up, then `true`.
- After three values are published over `kuksa.val.v2` (87 km/h, gear 3, 14 %), `/state.json` reads them back
  from QML, and the screenshot shows `87`, `D3` and `14%` in red.
- It stops in 0.3 s on SIGTERM and exits 0.

## What it is not

- Not a production HMI: a cockpit-side app that shows the signal plane end to end.
- It only reads signals; it never actuates.
- x86_64 only, for now.

## Build and publish

```sh
./scripts/publish/publish-container.sh parts/hpc/cockpit/app/qt-cluster 0.1.0
```
