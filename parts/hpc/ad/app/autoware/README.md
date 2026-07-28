# autoware — `VXERR-HADS-AOHA`

`ghcr.io/vxedge/parts/hpc/ad/app/autoware` · Autoware Universe · Apache-2.0 · **GPU passthrough**

The AD stack under test. Pins and re-labels the upstream prebuilt image rather than building
from source — a source build costs hours and changes nothing we measure.

```
podman pull ghcr.io/autowarefoundation/autoware:universe
podman image inspect --format '{{.Digest}}' ghcr.io/autowarefoundation/autoware:universe
../../../../../scripts/publish/publish-container.sh $PWD 0.1.0
```

**GPU:** shares the host GPU with `carla-server`. On a single ≥12GB card that pairing is
already tight — see `docs/TESTBED-SETUP.md`. Do not add DeepStream or Alpamayo to the same
run before the phase-2 gate closes; they are not gate-blocking and they contend for the same
VRAM.
