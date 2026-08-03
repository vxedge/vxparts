# scripts/publish/

One utility per artifact kind. All stamp `org.vxedge.*` OCI annotations at push time, read
straight from the part's own `meta.json` (`../../AGENTS.md`) — never hardcoded per script.

- `publish-container.sh` (planned) — docker/podman push for `hpc`/`gw`-class parts.
- `publish-vm-bundle.sh` — ORAS push for `zone`-class VM/kernel/QNX-IFS/AAOS guests that ship
  as a `vmlinuz`+`initrd.img` pair (the `zone-backend-contract` skill's guest-bundle
  convention). Exercised first by `linux-probe` (`../../parts/zone/linux/stack/probe-bundle`).
- `publish-vm-disk.sh` — ORAS push for parts that ship as **one complete disk image** instead
  of a kernel+initrd pair — a full appliance VM, not a zone-attached guest. First consumer:
  `../../parts/gw/nos/os/sonic-vs` (the SONiC-VS production-NOS twin, `docs/TASKS.md` #16).
  Sibling to `publish-vm-bundle.sh` rather than a generalization of it, per this directory's
  own "one utility per artifact kind" rule.

Requires the `oras` CLI (<https://oras.land>) for both VM-shaped scripts — confirmed
installed on at least one build host as of 2026-08-03; do not assume it's present everywhere
without checking (`oras version`).
