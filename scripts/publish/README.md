# scripts/publish/

One utility per artifact kind. Both stamp `org.vxedge.class/subtype/layer/backend/arch/license`
OCI annotations at push time (`../../AGENTS.md`).

- `publish-container.sh` (planned) — docker/podman push for `hpc`/`gw`-class parts.
- `publish-vm-bundle.sh` (planned) — ORAS push for `zone`-class VM/kernel/QNX-IFS/AAOS
  system images. Requires the `oras` CLI, which is **not yet installed** on the build host
  (confirmed 2026-07-26; `docker`/`podman` are present) — install before first use.

Neither script exists yet — see `../../TASKS.md` Migration section for the `linux-probe`
proof-of-concept that will exercise `publish-vm-bundle.sh` first.
