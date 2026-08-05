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

**Composite tooling landed 2026-08-05** (`scripts/publish/publish-composite.sh`, `vxparts/TASKS.md`
#19 item 3): `part.yaml` now declares this baseline's four `constituents:` at their tags; the
script cross-mounts each constituent's already-pushed manifest into this part's own repo (an
OCI index can only reference manifests within its own repository — a real registry, not just a
local one, is what surfaces that) and creates the index over the resulting digests. Verified
against a disposable local registry with two throwaway constituents end-to-end (mount, index
create, fetch, digest-match), and its error paths (wrong layer, missing `constituents:`) both
fail loudly rather than silently.

**Still blocked, but on content now, not tooling:** two of the four constituents —
`hpc/ad/config/autoware-params` and (for `sim-baseline`) `hpc/sim/config/scenarios` — are
themselves still `todo` (no payload yet, `vxpn.py lint`). Until those are populated and
published, running `publish-composite.sh` against this part fails at the `oras cp` step for
whichever constituent isn't there — which is the intended fail-fast behaviour, not a bug.
