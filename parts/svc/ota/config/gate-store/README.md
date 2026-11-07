# svc/ota/config/gate-store

The artifact store an `ota` service serves in the reference vehicles and the vxAPI gate: one artifact,
`gate-artifact` (1 MiB of zeros, sha256 `30e14955…09fcb58`), with its signed `root.json` and `targets.json`.

## What it is

- A store in vxota's format: `root.json`, `targets.json` and `artifacts/<sha256>`, written by `vxota keygen`
  and `vxota publish` (vxota v0.1.x). `root.json` expires in 2036.
- The store the reference sedans' OTA check reads: it serves `root.json` on `:9900`.
- Pinned in a vehicle as `config.artifacts: ghcr.io/vxedge/parts/svc/ota/config/gate-store@sha256:<digest>`,
  which vxedge fetches into its part cache and mounts read-only.

## What it is not

- Not an update for any real device, and not secret: it is test data. The root signing key that produced it
  is not part of this part and was never published, so nothing new can be signed into this store.

## Publish

```sh
./scripts/publish/publish-files.sh parts/svc/ota/config/gate-store 0.1.0
```
