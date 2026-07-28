# parts/

Loadables, one directory per part: `<class>/<subtype>/<layer>/<name>/`. See `../AGENTS.md`
for the class/subtype/layer definitions and `../TASKS.md` for what's planned vs. migrated.

Each part directory holds a build recipe + README only — no composition data. Which part
goes into which zone/vehicle is decided solely by the vehicle/experiment manifest
(`vxperiments`), not by anything in this directory.

## Anatomy of a part

```
parts/<class>/<subtype>/<layer>/<name>/
├── part.yaml       # required — licence, upstream pin, GPU, SBOM, extra annotations
├── README.md       # required — what it is, how to build it, what it costs
└── Containerfile   # the build recipe: Containerfile OR build.sh, never both
    | build.sh      #   (config-layer parts have neither: the part IS its files)
```

**`part.yaml` never restates class/subtype/layer/name** — those come from the path, which is
the address. Duplicating them is exactly the drift the no-catalog rule exists to prevent, and
`vxpn.py meta` rejects a `part.yaml` that tries.

```yaml
license: MIT AND CC-BY-NC-4.0    # required; SPDX where one applies
gpu: passthrough                 # optional
build: recipe                    # optional — overrides the layer default
upstream:                        # optional — for parts that pin/re-label an upstream image
  ref: docker.io/carlasim/carla:0.9.15
  digest: sha256:...             # required before publish; injected as the build's UPSTREAM
sbom: {format: cyclonedx-json, path: sbom.cdx.json}   # optional, non-blocking
annotations: {headless: "true"}  # free-form; each becomes org.vxedge.<key>
```

Every key surfaces as an `org.vxedge.*` label/annotation on the published artifact, so
classification and licence travel with the bytes rather than living only in this repo.

## How a part is produced

Decided by the part's **layer** (`../schema/taxonomy.yaml` `layers[].build`), overridable
per part:

| `build` | Recipe | Publish script | Artifact |
|---|---|---|---|
| `recipe` | `Containerfile` | `publish-container.sh` | OCI image, `org.vxedge.*` labels |
| `recipe` | `build.sh` | `publish-vm-bundle.sh` | ORAS artifact, `org.vxedge.*` annotations |
| `files` | none — the part is its files | `publish-files.sh` | ORAS artifact |
| `composite` | none — indexed, not built | *(pending, Track P)* | OCI image index |

Every publish script derives the registry ref *and* the VXPN from the part's own directory
path, so neither is ever passed in and neither can be mistyped.

```
../scripts/resolve-pin.sh <part-dir> [--write]   # pin upstream tag -> digest (no image pull)
../scripts/sbom.sh <part-dir>        # CycloneDX SBOM, non-blocking when tooling is absent
../scripts/vxpn.py lint     # validate every part against its layer's build contract
../scripts/vxpn.py scan     # VXPN collision gate
../scripts/vxpn.py meta <part-dir>   # what will be stamped on the artifact
```

Current tree — `zone/linux/stack/probe-bundle` is published; the eight `hpc/{ad,sim}` parts
are the phase-2 critical path (`../TASKS.md`); the rest is skeleton awaiting migration:

```
zone/{linux,qnx,zephyr,freertos,aaos,mcu}/...
hpc/ad/{middleware/{ros2-humble,carla-ros-bridge},app/autoware,config/autoware-params,stack/ad-baseline}
hpc/sim/{app/carla-server,config/scenarios,stack/sim-baseline}
hpc/{cockpit,motion}/...
gw/{tcu,nos,5gc,ran,dp}/...
agent/{probe,load,collect}/...
svc/{ota,telemetry,observability,signal}/...
```
