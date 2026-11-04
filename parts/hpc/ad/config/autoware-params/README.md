# autoware-params — `VXEUV-HADS-CCSC`

`ghcr.io/vxedge/parts/hpc/ad/config/autoware-params` · config layer · ORAS artifact

Baseline launch parameters and the documented per-topic QoS for the `autoware_carla_interface`
bridge inside the pinned `autoware` part. A run's parameters are an input to its result, so they
are a versioned part.

| File | What it pins |
|---|---|
| `carla-interface.params.yaml` | The bridge's documented parameters at upstream defaults, plus explicit synchronous mode and a 0.05 s step |
| `qos.yaml` | Only the QoS the upstream README documents (`reliable` on the front camera image and info) |

## What this is, and is not

A **baseline**, not a tuned profile. Parameter names come from the upstream README (CARLA 0.9.15,
Humble). The topics the bridge publishes and the ego control topic it subscribes to are not
fully listed there, so this part does not invent QoS for them: they stay on the image's defaults.
Map, spawn point and sensor mapping belong to the scenario, not to this part. Nothing here has
been run against a live CARLA server; that is exp-011's job and needs a Tier 2 GPU host.

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```
