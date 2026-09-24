# vxparts

The unified loadable registry for the vxedge testbed. It holds zone VM/RTOS bundles, central-compute containers, gateway images, platform services and agents, all published to GHCR via OCI/ORAS. It contains **build recipes and descriptors**. Proprietary components (QNX, NVIDIA SDKs) are recipe-only and never redistributed.

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![CI](https://github.com/vxedge/vxparts/actions/workflows/parts.yml/badge.svg)](https://github.com/vxedge/vxparts/actions/workflows/parts.yml)

vxedge is an open, all-software testbed for mapping 5G network slices onto zonal and central software-defined-vehicle (SDV) E/E architectures on a single machine. Every published number ships with the manifest and image digests that produced it.

## Layout

Parts are classified by pull path, `parts/<class>/<subtype>/<layer>/<name>/`. Each part has a
`part.yaml` descriptor that declares its licence, and that licence is stamped onto the
published artifact. Part numbers are computed from the pull path, as described in
[`PART-NUMBERING.md`](PART-NUMBERING.md).

| Class | Examples |
|---|---|
| `zone` | Linux probe bundle (virtual ECU guest) |
| `gw` | Open5GS core, UERANSIM RAN, SONiC-VS NOS twin |
| `hpc` | ROS 2 Humble, CARLA client/server, Autoware |
| `svc` | vxota container, Eclipse Kuksa databroker |
| `veh`, `ctl` | Vehicle reference configs, manifest schema |

## Quickstart

```bash
pip install PyYAML
./scripts/vxpn.py lint      # descriptor + licence checks (as CI runs them)
./scripts/vxpn.py scan      # list parts with their computed part numbers
```

Third-party licences for each part are summarised in [`NOTICE`](NOTICE).

## Links

- Site: <https://vxedge.dev>
- Architecture: [`docs/ARCHITECTURE.md`](https://github.com/vxedge/docs/blob/main/ARCHITECTURE.md)
- Results: [`docs/RESULTS.md`](https://github.com/vxedge/docs/blob/main/RESULTS.md) · Roadmap: [`docs/ROADMAP.md`](https://github.com/vxedge/docs/blob/main/ROADMAP.md)
- Contributing: [CONTRIBUTING](https://github.com/vxedge/.github/blob/main/CONTRIBUTING.md) · Security: [SECURITY](https://github.com/vxedge/.github/blob/main/SECURITY.md)
- License: Apache-2.0 ([`LICENSE`](LICENSE))
