# scenarios — `VXEQC-HSIM-CD0I`

`ghcr.io/vxedge/parts/hpc/sim/config/scenarios` · config layer · ORAS artifact

CARLA scenario definitions: map, weather, actor population, sensor rig, and **fixed-tick
synchronous mode** settings.

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```

Synchronous fixed-tick is not a performance preference — it is what makes a run repeatable.
In asynchronous mode CARLA's tick rate varies with GPU load, so the offered ADAS load would
change between runs and exp-011's numbers would not be comparable across arms.
