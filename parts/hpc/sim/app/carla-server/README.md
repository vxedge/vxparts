# carla-server — `VXER8-HSIM-AGF3`

`ghcr.io/vxedge/parts/hpc/sim/app/carla-server` · CARLA 0.9.15 · **MIT code / CC-BY-4.0 assets** · **GPU passthrough**

The world and sensor source for exp-011. Its sensor streams *are* the measured ADAS load,
which is what makes exp-011 a real-traffic experiment rather than a synthetic one.

> **Licences.** CARLA's code is MIT. Its assets (maps, vehicle and pedestrian models) are
> CC BY 4.0: CARLA 0.9.15's README says "CC-BY", and the content release it pins
> (`Util/ContentVersions.txt`: `20231108_c5101a5`) carries the CC BY 4.0 licence text. CC BY
> requires attribution and allows no added restrictions; it has no non-commercial term. The
> server itself is Unreal Engine 4, under Epic's EULA, and the upstream image's base layers are
> NVIDIA's (CUDA 10.1, Vulkan). This part is a relabel of the official `carlasim/carla:0.9.15`
> image by digest and is not published.

```
podman pull docker.io/carlasim/carla:0.9.15
podman image inspect --format '{{.Digest}}' docker.io/carlasim/carla:0.9.15
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

Runs headless: the host has no display, and rendering to one would perturb the measurement.
