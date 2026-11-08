# manifest-schema — `VXEMA-CSCH-C1VB`

`ghcr.io/vxedge/parts/ctl/schema/config/manifest-schema` · config layer · ORAS artifact

The JSON Schema for `vxedge`'s workspace document kinds (`experiment` | `vehicle` | `road` |
`baseline` | `component`, `docs/ARCHITECTURE.md` §6.0), generated from `vxedge-core`'s own Rust
manifest types rather than hand-maintained — so it can never drift from what the daemon
actually accepts. Published as a part (not just committed to `vxedge`) so an editor (VS Code
YAML extension, etc.) can point at one digest-addressed, `oras pull`-able schema regardless of
which repo a workspace author has checked out.

This is the `ctl` class's first instance (Track D consequence d): a
control-plane/tooling artifact consumed by `vxedge` itself, not a loadable workload — hence its
own class rather than shoehorning it into `svc`.

## Status: no payload yet

This part has no payload. `vxedge-core` does not emit a JSON Schema for its workspace document
structs (`Experiment`, `Vehicle`, `Road`, `Baseline`, `Component`), and a hand-written schema
would drift from those Rust types, so none is committed here. A payload is published with
`publish-files.sh`, like any other `config`-layer part:

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```
