# parts/zone/wasm/app/reflector-capsule

The first WebAssembly capsule: a UDP reflector for `backend: wasm-capsule` zone nodes, for a sensor
or ECU node simulable as a sandboxed control loop rather than a full guest kernel.

**Classification**: `class=zone`, `subtype=wasm`, `layer=app`.

**Guest contract**: a WASI 0.2 command component. `VX_NODE` names the node, stdout and stderr are
the node's log, `eth0` is addressed before it starts, and it has no filesystem. It echoes every
datagram on `0.0.0.0:9800`, the same reflector contract as the `linux-probe` bundle.

## Build

```
./build.sh [out-dir]     # default: ./bundle
```

Output is gitignored. It contains `reflector-capsule.wasm` and a digest-stamped `meta.json`.

## Publish

```
../../../../../scripts/publish/publish-wasm.sh ./bundle ghcr.io/vxedge/parts/zone/wasm/app/reflector-capsule:<semver>
```

## Use

```yaml
parts:
  - ref: ghcr.io/vxedge/parts/zone/wasm/app/reflector-capsule
    digest: sha256:<digest>
    kind: wasm
    target_ids: <function>
```
