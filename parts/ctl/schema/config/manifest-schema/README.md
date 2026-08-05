# manifest-schema — `VXEMA-CSCH-C1VB`

`ghcr.io/vxedge/parts/ctl/schema/config/manifest-schema` · config layer · ORAS artifact

The JSON Schema for `vxedge`'s workspace document kinds (`experiment` | `vehicle` | `road` |
`baseline` | `component`, `docs/ARCHITECTURE.md` §6.0), generated from `vxedge-core`'s own Rust
manifest types rather than hand-maintained — so it can never drift from what the daemon
actually accepts. Published as a part (not just committed to `vxedge`) so an editor (VS Code
YAML extension, etc.) can point at one digest-addressed, `oras pull`-able schema regardless of
which repo a workspace author has checked out.

This is the `ctl` class's first instance (Track D consequence d, `vxparts/TASKS.md`): a
control-plane/tooling artifact consumed by `vxedge` itself, not a loadable workload — hence its
own class rather than shoehorning it into `svc`.

## Status: todo, no payload yet

Generating the real schema is Rust codegen work in the `vxedge` repo, not something to
fabricate here:

1. Add `schemars` (or equivalent) to `vxedge-core`, derive `JsonSchema` on the workspace
   document structs (`Experiment`, `Vehicle`, `Road`, `Baseline`, `Component`).
2. A small binary/script in `vxedge-core` (or a `cargo xtask`) that emits the combined schema
   as `manifest-schema.json`.
3. That output becomes this part's payload, published via `publish-files.sh` like any other
   `config`-layer part.

Left `todo` deliberately — same discipline as `hpc/ad/config/autoware-params` and
`veh/car/config/reference-sedan-6zone` — rather than hand-writing a schema that would
immediately drift from the real Rust types it's supposed to be generated from.

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```
