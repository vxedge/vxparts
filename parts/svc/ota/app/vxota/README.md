# vxota — `VXE92-SOTA-ATPS`

`ghcr.io/vxedge/parts/svc/ota/app/vxota` · Apache-2.0 · no GPU

The OTA server (`keygen`/`publish`/`serve`) — H4's own service under test (OTA co-location
vs. ADAS slice SLA), `ARCHITECTURE.md` §8. Deployed on demand via `vxedge ota up
--experiment <manifest>`, stateless across runs apart from its `config.artifacts` directory.

## What it packages

`vxota` from the [vxota](https://github.com/vxedge/vxota) v0.1.1 release (commit `621a51f`), the x86_64 GNU
build, verified against the release tarball's sha256 (`part.yaml`) before it is packaged. The source lives in
that repo; this part owns the published image. Its `upstream` pin is the Debian runtime base.

The image's entrypoint is `vxota`, so a placed service runs it as `vxota serve --artifacts-dir ... --listen ...`.

## Build and publish

```sh
./parts/svc/ota/app/vxota/stage.sh
./scripts/publish/publish-container.sh parts/svc/ota/app/vxota 0.1.1
```

Bump the release, commit and checksum in `part.yaml` and `stage.sh` together when vxota moves.

## Dev/test builds

For local iteration, build straight from a `vxota` checkout instead — see that repo's own
`Containerfile.dev` (compiles from source in one step, no cross-repo staging). This part's
own recipe is the one `vxedge ota up` actually pulls; the dev one is not published anywhere.
