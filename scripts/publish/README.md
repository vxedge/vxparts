# scripts/publish/

One utility per artifact kind. All stamp `org.vxedge.*` OCI annotations at push time, read
straight from the part's own `meta.json` (`../../AGENTS.md`) — never hardcoded per script.

- `publish-container.sh` — podman build + push for `hpc`/`gw`-class container parts;
  `org.vxedge.*` classification lands as OCI labels, verified to survive the build. First
  real consumer: `../../parts/svc/ota/app/vxota` (`docs/ROADMAP.md` #23).
- `publish-files.sh` — ORAS push for a `config`-layer part: a directory of files (params,
  scenario defs), not a container — nothing executes, but it's still versioned and
  digest-addressed like every other loadable.
- `publish-vm-bundle.sh` — ORAS push for `zone`-class VM/kernel/QNX-IFS/AAOS guests that ship
  as a `vmlinuz`+`initrd.img` pair (the `zone-backend-contract` skill's guest-bundle
  convention). Exercised first by `linux-probe` (`../../parts/zone/linux/stack/probe-bundle`).
- `publish-vm-disk.sh` — ORAS push for parts that ship as **one complete disk image** instead
  of a kernel+initrd pair — a full appliance VM, not a zone-attached guest. First consumer:
  `../../parts/gw/nos/os/sonic-vs` (the SONiC-VS production network OS, `docs/ROADMAP.md` #16).
  Sibling to `publish-vm-bundle.sh` rather than a generalization of it, per this directory's
  own "one utility per artifact kind" rule.
- `publish-composite.sh` — builds a `stack`-layer composite: an OCI image index over
  constituent parts that are each already published (their own `constituents:` list in
  `part.yaml`), cross-mounting each into the composite's own repo before indexing (an index
  can only reference manifests within its own repository). First consumers:
  `../../parts/hpc/ad/stack/ad-baseline`, `../../parts/hpc/sim/stack/sim-baseline`
  (`vxparts/TASKS.md` #19 item 3) — both still blocked on a constituent's own content, not on
  this tooling.

Requires the `oras` CLI (<https://oras.land>) for every script but `publish-container.sh`
(podman only) — confirmed installed on at least one build host as of 2026-08-03; do not
assume it's present everywhere without checking (`oras version`).
