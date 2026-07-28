# carla-server — `VXER8-HSIM-AGF3`

`ghcr.io/vxedge/parts/hpc/sim/app/carla-server` · CARLA 0.9.15 · **MIT code / CC-BY-NC assets** · **GPU passthrough**

The world and sensor source for exp-011. Its sensor streams *are* the measured ADAS load,
which is what makes exp-011 a real-traffic experiment rather than a synthetic one.

> **Licence flag.** CARLA's code is MIT but its bundled assets (maps, vehicle and pedestrian
> models) are **CC-BY-NC** — non-commercial. This is the only non-commercial term sitting
> directly on the phase-2 critical path. Confirm the research-use reading before this part is
> tagged and before any exp-011 numbers are published. Tracked under the workspace licensing
> review in `docs/TASKS.md`.

```
podman pull docker.io/carlasim/carla:0.9.15
podman image inspect --format '{{.Digest}}' docker.io/carlasim/carla:0.9.15
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

Runs headless: the host has no display, and rendering to one would perturb the measurement.
