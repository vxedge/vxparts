# carla-client — `VXECL-HADS-M70H`

`ghcr.io/vxedge/parts/hpc/ad/middleware/carla-client` · MIT · no GPU

The CARLA **0.9.15** Python client API on ROS2 Humble — the version-pinning artifact for the
CARLA↔ROS2 boundary on the `exp-011` critical path.

## Why this replaced `carla-ros-bridge`

The original part built `carla-simulator/ros-bridge`. Verified 2026-07-28:

| | |
|---|---|
| `ros-bridge` master last commit | **2022-07-22** ("Update CARLA version to 0.9.13") |
| newest activity on *any* branch | 2023-11-15 (`leaderboard-2.x`) |
| its README requires | CARLA **0.9.13** |
| our `carla-server` pins | CARLA **0.9.15** |

It built and installed cleanly, which is what made it the dangerous option: a bridge whose
source targets a different server version than the one under test still produces numbers —
just not ones worth publishing. (The CARLA *simulator* is very much alive — commit
2026-07-14 — the bridge repo is the frozen one. Two different repos.)

The supported path is **`autoware_carla_interface`**, a ROS2 package inside
`autoware_universe` whose compatibility table reads Ubuntu 22.04 / Humble / CARLA 0.9.15 —
exactly our pins — and which was last touched 2026-07-24. It ships inside the `autoware`
part; what it needs from this repo is a matching CARLA client, which is this part.

## Build

```
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

The build imports `carla` as its last step, so a client that stops installing fails here
rather than at experiment time.

## Forward path, deliberately not taken yet

`autowarefoundation/carla-autoware-extension` (very active — commit 2026-07-24) targets
CARLA `ue5-dev`'s **native DDS publishers**, removing the bridge process from the data path
entirely. Its README states it "does not replace `autoware_carla_interface` for 0.9.15" — it
is the UE5-generation track. Revisit when moving off 0.9.15; not a phase-2 item.
