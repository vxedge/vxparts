# ad-baseline — `VXES9-HADS-S7Q1`

`ghcr.io/vxedge/parts/hpc/ad/stack/ad-baseline` · stack layer · composite

One pullable unit indexing the AD side of exp-011:

| Constituent | VXPN |
|---|---|
| `hpc/ad/middleware/ros2-humble` | `VXE8J-HADS-MFER` |
| `hpc/ad/middleware/carla-client` | `VXECL-HADS-M70H` |
| `hpc/ad/app/autoware` | `VXERR-HADS-AOHA` |
| `hpc/ad/config/autoware-params` | `VXEUV-HADS-CCSC` |

The CARLA↔ROS2 link is `autoware_carla_interface`, which ships inside the `autoware`
constituent; `carla-client` supplies the matching CARLA 0.9.15 client API. The former
`carla-ros-bridge` part was retired 2026-07-28 — see `carla-client/README.md`.

**Blocked:** the composite-part convention (an OCI image index over constituent parts) is not
implemented yet — `docs/TASKS.md` Track P. Until it lands, an experiment manifest references
the four constituents individually. Build this last; it is the only critical-path part that
needs new publish tooling rather than new content.
