# autoware-params — `VXEUV-HADS-CCSC`

`ghcr.io/vxedge/parts/hpc/ad/config/autoware-params` · config layer · ORAS artifact

Autoware launch parameters and **explicit per-topic DDS QoS profiles**. Config is a part in
its own right because a run's parameters are as much an input to its result as the code that
reads them — an unversioned params file silently breaks reproducibility (§13).

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```

Empty until the bridge's topic set is known — populate once `carla-ros-bridge` builds, since
the QoS profiles must match the topics it actually publishes.
