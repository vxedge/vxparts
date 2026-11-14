# ros2-humble — `VXE8J-HADS-MFER`

`ghcr.io/vxedge/parts/hpc/ad/middleware/ros2-humble` · ROS2 Humble · Apache-2.0 · no GPU

The shared ROS2 layer for every `hpc/ad` part. It exists as a separate part so that
`carla-ros-bridge` and `autoware` are forced to agree on one distro and one RMW by
construction, rather than by convention.

```
podman pull ros:humble-ros-base
podman image inspect --format '{{.Digest}}' ros:humble-ros-base   # paste into Containerfile
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

**Transport:** `rmw_fastrtps_cpp`, set explicitly — QoS and transport are measured
variables in this testbed, so they are never left to a default that could shift upstream.
Swapping to `rmw_zenoh` is a separate part, not an env override (Track D dimension 2).

## Published

`ghcr.io/vxedge/parts/hpc/ad/middleware/ros2-humble:0.1.0`, `sha256:63d1fc55b689c82420c51217b7915438dc9495656de135069e96ad72bb5d75df` (2026-07-28), the digest
`hpc/ad/stack/ad-baseline` pins. Checked again on 2026-11-14 through `carla-client` 0.1.0, which
is built on this digest: a `ros2 topic pub` reached a `ros2 topic echo` over `rmw_fastrtps_cpp`.
