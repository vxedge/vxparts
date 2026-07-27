# parts/

Loadables, one directory per part: `<class>/<subtype>/<layer>/<name>/`. See `../AGENTS.md`
for the class/subtype/layer definitions and `../TASKS.md` for what's planned vs. migrated.

Each part directory holds a build recipe + README only — no composition data. Which part
goes into which zone/vehicle is decided solely by the vehicle/experiment manifest
(`vxperiments`), not by anything in this directory.

Current skeleton (empty until content migrates from `vxzones`/`vxcompute` — see
`../TASKS.md` Migration section):

```
zone/{linux,qnx,zephyr,freertos,aaos}/...
hpc/{ad,sim,cockpit,motion}/...
gw/{tcu,nos}/...
agent/
svc/
```
