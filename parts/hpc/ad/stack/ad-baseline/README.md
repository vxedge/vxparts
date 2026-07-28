# ad-baseline — `VXES9-HADS-S7Q1`

`ghcr.io/vxedge/parts/hpc/ad/stack/ad-baseline` · stack layer · composite

One pullable unit indexing the AD side of exp-011:

| Constituent | VXPN |
|---|---|
| `hpc/ad/middleware/ros2-humble` | `VXE8J-HADS-MFER` |
| `hpc/ad/middleware/carla-ros-bridge` | `VXEUS-HADS-M7BO` |
| `hpc/ad/app/autoware` | `VXERR-HADS-AOHA` |
| `hpc/ad/config/autoware-params` | `VXEUV-HADS-CCSC` |

**Blocked:** the composite-part convention (an OCI image index over constituent parts) is not
implemented yet — `docs/TASKS.md` Track P. Until it lands, an experiment manifest references
the four constituents individually. Build this last; it is the only critical-path part that
needs new publish tooling rather than new content.
