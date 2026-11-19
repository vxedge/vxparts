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

**Not republished (decision 2026-11-16).** vxedge adds nothing to CARLA's official image, and
that image already carries the engine and assets publicly, so a vehicle names it directly,
pinned by digest. Off-screen rendering is CARLA's `-RenderOffScreen` argument (the image's own
command omits it), passed with the part entry's `run.args`, which replace the image's command:

```yaml
parts:
  - ref: docker.io/carlasim/carla
    digest: sha256:1af47c314443f4a2d0869ac399c5b5eabde138a5bc39dd31dcbb1540e22f5588
    target_ids: [carla]
    run:
      args: ["/bin/bash", "CarlaUE4.sh", "-RenderOffScreen"]
```

There is no simulation stack part: an OCI index can only reference manifests in its own registry, so
CARLA's image cannot be one of its constituents. A vehicle lists this entry beside its other parts.

The image runs as user `carla` in `/home/carla`. The Containerfile here only relabels it for
local builds and is not published.
