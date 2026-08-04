# vxota — `VXE92-SOTA-ATPS`

`ghcr.io/vxedge/parts/svc/ota/app/vxota` · MIT OR Apache-2.0 · no GPU

The OTA server (`keygen`/`publish`/`serve`) — H4's own service under test (OTA co-location
vs. ADAS slice SLA), `ARCHITECTURE.md` §8. Deployed on demand via `vxedge ota up
--experiment <manifest>`, stateless across runs apart from its `config.artifacts` directory.

## Why this is a packaging-only recipe (no source here)

`vxota`'s Rust source lives in its own repo, `vxedge/vxota` — that repo owns the code
(`vxota/AGENTS.md`: *"the code lives here"*), this part owns the published artifact,
matching every other loadable's registry/source split. Unlike `autoware`/`carla-server`,
which pull a *public* upstream image, `vxota` is a *private* first-party repo — this
Containerfile can't `git clone` it at build time without baking a credential into the
build, which this workspace's own conventions already argue against. So the binary is
built **outside**, from a checkout of `vxedge/vxota` at the pinned commit recorded in
`part.yaml`'s `annotations.vxota-source-commit`, and staged into `bin/vxota` before
`publish-container.sh` ever runs. This Containerfile only packages what's already built —
its own `upstream` pin is the Debian runtime base, the actual external dependency here.

## Build

From a checkout of `vxedge/vxota` at the commit `part.yaml` names:

```sh
cargo build --release -p vxota
cp target/release/vxota <this-dir>/bin/vxota
```

Then, from `vxparts`:

```sh
./scripts/publish/publish-container.sh parts/svc/ota/app/vxota 0.1.0
```

Re-run both steps and bump `part.yaml`'s `annotations.vxota-source-commit` whenever
`vxota`'s own repo moves — the recorded commit is this part's only link back to the
source that produced it, so it drifting from the actual binary would silently break
reproducibility the same way an unpinned upstream tag would.

## Dev/test builds

For local iteration, build straight from a `vxota` checkout instead — see that repo's own
`Containerfile.dev` (compiles from source in one step, no cross-repo staging). This part's
own recipe is the one `vxedge ota up` actually pulls; the dev one is not published anywhere.
