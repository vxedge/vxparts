# carla-ros-bridge — `VXEUS-HADS-M7BO`

`ghcr.io/vxedge/parts/hpc/ad/middleware/carla-ros-bridge` · MIT · no GPU

Translates CARLA sensor streams into ROS2 topics Autoware consumes. **This is the exp-011
blocker and the highest integration risk in the critical path**: it pins the CARLA version
*and* the ROS2 distro at once, so its version triple must be settled before either
neighbouring part is tagged. Build it second, not last.

Built from source (no official image tracks recent CARLA releases). Records the built commit
at `/opt/bridge/BRIDGE_SHA` so the image documents its own inputs.

```
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

Depends on the `ros2-humble` part by digest — resolve that part's published digest into
this Containerfile's `UPSTREAM` before building.
