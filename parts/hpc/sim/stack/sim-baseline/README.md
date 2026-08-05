# sim-baseline — `VXEAO-HSIM-S5WY`

`ghcr.io/vxedge/parts/hpc/sim/stack/sim-baseline` · stack layer · composite

One pullable unit indexing the simulation side of exp-011:

| Constituent | VXPN |
|---|---|
| `hpc/sim/app/carla-server` | `VXER8-HSIM-AGF3` |
| `hpc/sim/config/scenarios` | `VXEQC-HSIM-CD0I` |

**Composite tooling landed 2026-08-05**, same as `ad-baseline` (`scripts/publish/publish-composite.sh`)
— `part.yaml` declares this baseline's two `constituents:`. **Still blocked on content**:
`hpc/sim/config/scenarios` is itself still `todo` (no payload yet); `publish-composite.sh`
fails at the `oras cp` step for it until that's populated. Inherits `carla-server`'s
CC-BY-NC asset terms — a composite is not a licence laundry.
