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

**Composite tooling landed 2026-08-05** (`scripts/publish/publish-composite.sh`):
`part.yaml` now declares this baseline's four `constituents:` at their tags; the
script cross-mounts each constituent's already-pushed manifest into this part's own repo (an
OCI index can only reference manifests within its own repository — a real registry, not just a
local one, is what surfaces that) and creates the index over the resulting digests. Verified
against a disposable local registry with two throwaway constituents end-to-end (mount, index
create, fetch, digest-match), and its error paths (wrong layer, missing `constituents:`) both
fail loudly rather than silently.

**Published 2026-11-04** at `0.1.0`, digest `sha256:53b270d42bfa04de90f192a8681355380e29ed7b41b6e64cb3e5d5f5037ca132`
(index over the four constituents, digests verified). Constituent digests:

| Constituent | Digest |
|---|---|
| `middleware/ros2-humble` | `sha256:63d1fc55b689c82420c51217b7915438dc9495656de135069e96ad72bb5d75df` |
| `middleware/carla-client` | `sha256:832dedf3a03e4b3f9eefc5f4955bce24ab7f30878579d5db2068f860a3e9d436` |
| `app/autoware` | `sha256:945fa07033200767732071cb9801d49ffaf7fb52988dba4a5b87c3f6aaa6c464` (upstream pinned at `sha256:df96858b…`) |
| `config/autoware-params` | `sha256:1c3045aacf4431cb6974458d3bcd399a4c3dca37d5f1216cfd2f8c291eb098c9` |

**What this is:** the AD stack's parts, pinned and indexed. It has not been run against a CARLA
server: the closed loop needs a Tier 2 GPU host (exp-011), and `autoware-params` is a baseline,
not a tuned profile.
