# reference-sedan-6zone — `VXEFJ-VCAR-C2K3`

`ghcr.io/vxedge/parts/veh/car/config/reference-sedan-6zone` · config layer · ORAS artifact

A reusable **vehicle structural model** (`kind: vehicle` per `docs/ARCHITECTURE.md` §6.0.1:
`zones`/`devices`/`functions`/`links`/`channels`) covering all six canonical zone roles
(`front-left`, `front-right`, `rear-left`, `rear-right`, `central-hpc`, `gateway` — the fixed
vocabulary from ARCHITECTURE.md §3). Published here so an experiment workspace can pull one
digest-addressed structural model instead of hand-copying a `vehicle.yaml` — the same
motivation as `hpc/ad/config/autoware-params`: an unversioned or divergently-copied structural
file is a reproducibility gap, not a convenience shortcut.

This part is the `veh` class's first instance (Track D consequence a, `vxparts/TASKS.md`):
vehicle models are `config`-layer parts, numbered by the same VXPN scheme as every other part
— no separate model-number scheme, so sharing a vehicle stays a single `oras pull`.

## Status: todo, no payload yet

Every existing vehicle document in `vxperiments` (`exp-001-ws/vehicle.yaml`,
`exp-002-ws/vehicle.yaml`, `exp-002b-ws/vehicle.yaml`, `exp-010-ws/vehicle.yaml`,
`exp-014/vehicle.yaml`) is scoped to its own experiment (two zones for `exp-001-ws`'s H1
isolation test, etc.) — none is the full six-zone reference topology this part name promises.
Populating this part means either:

1. Authoring a genuinely new six-zone reference topology (front-left/front-right/rear-left/
   rear-right/central-hpc/gateway, one device each) that no single experiment needs today, or
2. Deferring to Track M (`vxmodels`) to render this structural model from its SysML v2 source
   once that model exists — `vxmodels` is the design authority, this part would be the
   manifest-shaped publication of it (root `CLAUDE.md` §6.3).

Neither is a data-entry task; both are a design decision for whoever pulls this thread next.
Left `todo` deliberately rather than inventing placeholder topology data, per the same
discipline already applied to `hpc/ad/config/autoware-params` and `hpc/sim/config/scenarios`
(both scaffolded empty until their real inputs exist).

```
../../../../../scripts/publish/publish-files.sh $PWD 0.1.0
```
