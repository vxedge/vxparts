# parts/svc/signal/app/kuksa-can-provider

The CAN side of the signal plane: Eclipse Kuksa's CAN provider. It decodes CAN frames with a DBC
file, maps the CAN signals to COVESA VSS paths and publishes them to a Kuksa databroker
(`svc/signal/app/kuksa-databroker`). It reads frames from a SocketCAN interface, or replays a
recorded CAN trace with no CAN interface at all.

Classification: `class=svc`, `subtype=signal`, `layer=app`.

## Upstream pin

Thin relabel of Eclipse Kuksa's own published, multi-arch OCI image. There is no source build.

- `upstream.ref: ghcr.io/eclipse-kuksa/kuksa-can-provider/can-provider:0.5.1`
- `upstream.digest`: `sha256:41f5abffe30be4dd0bf6d82f28ca149d327e2d6de8619b562a12035a30da0c8e`,
  resolved 2026-11-13 with `oras resolve` (image index: amd64, arm64).
- Version: `0.5.1`, the latest release as of pinning (published 2026-10-28).
- Read from the 0.5.1 image config with `oras`: entrypoint `./dbcfeeder`, working directory
  `/dist`, no exposed port. The provider is a gRPC client of the databroker.

## What the image runs by default

With no arguments the provider reads `config/dbc_feeder.ini` from the image and:

- decodes with the sample DBC, `Model3CAN.dbc`;
- maps with `mapping/vss_6.0/vss_dbc.json`, which is VSS release 6.0, the release the databroker
  part loads by default;
- replays the sample trace `candump.log` once, with no CAN interface;
- connects to `grpc://127.0.0.1:55555`, without TLS or a token.

The settings an experiment changes most often:

| Setting | Argument | Environment variable |
|---|---|---|
| Databroker address | `ADDRESS` (positional) | `KUKSA_ADDRESS` |
| DBC file | `--dbcfile` | `DBC_FILE` |
| Trace to replay | `--dumpfile` | `CANDUMP_FILE` |
| Replay the trace in a loop | `--infinite` | none |
| VSS mapping file | `--mapping` | `MAPPING_FILE` |
| Read a SocketCAN interface | `--use-socketcan`, `--canport` | `CAN_PORT` |

The full list is in upstream's
[configuration guide](https://github.com/eclipse-kuksa/kuksa-can-provider/blob/0.5.1/doc/configuration.md).

## Sample data

The upstream image carries a DBC file and a short recorded CAN trace from a production car, so the
part produces realistic signal traffic with nothing else mounted. Upstream's README describes
both. The DBC comes from the [model3dbc](https://github.com/joshwardell/model3dbc) project and is
MIT-licensed; `part.yaml` records that as `sample-dbc-license`.

## License

**Apache-2.0**, from the upstream repository's SPDX metadata and the 0.5.1 image's own
`org.opencontainers.image.licenses` label. The sample DBC is MIT-licensed third-party data.

## Build

```
VXPARTS_NO_PUSH=1 ./scripts/publish/publish-container.sh parts/svc/signal/app/kuksa-can-provider 0.1.0
```

Without `VXPARTS_NO_PUSH=1` the script also pushes the image.

## Run

Beside a databroker that listens on `55555` in the same network namespace:

```
podman run --rm <ref>
```

Against a databroker elsewhere, replaying in a loop:

```
podman run --rm -e KUKSA_ADDRESS=grpc://<databroker>:55555 <ref> --infinite
```

## What this part does not do

- No vehicle document starts it. Adding it to a vehicle is a change to that vehicle's document.
- It does not create a CAN interface. The SocketCAN mode needs one in the container's network
  namespace, for example a `vcan` link; the default replay mode needs none.
- vxedge parses a device's `dbc:` field and does not act on it. This part does not change that.

## Publishing

This part has not been published to the registry yet. It is one of the choices in the manual
`publish` workflow.

## Verified 2026-11-13 (0.5.1)

- The local build was clean, and all 12 `org.vxedge.*` labels were intact.
- `vxpn.py lint` and `vxpn.py scan` pass, with no part-number collision.
- Smoke test under rootless Podman, in one pod with `kuksa-databroker` 0.7.1 started with
  `--insecure`: the provider connected, found its 34 mapped VSS entries registered in the databroker
  and replayed `candump.log`. Afterwards `databroker-cli get` returned a value for `Vehicle.Speed`
  and `Vehicle.Powertrain.Transmission.CurrentGear`. Signals whose frames the short trace does not
  carry stayed `NotAvailable`.
