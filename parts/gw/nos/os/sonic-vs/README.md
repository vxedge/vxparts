# parts/gw/nos/os/sonic-vs

The SONiC-VS production-NOS twin (`docs/TASKS.md` #16, `ARCHITECTURE.md` §7): a community
SONiC virtual-switch image, fed the same slice/VLAN intent `vxedge_core::sonic` renders from a
`GatewayPlan`, to prove that intent expresses identically on a real production NOS. **Not
timing-representative** — every latency/jitter number this project has published still runs
against the Linux-native `vxgateway` path (`network.data_plane: kernel-bridge|ovs`). This part
exists to prove config portability, never to carry measured traffic.

**Not a zone-attached guest.** SONiC-VS does not follow the `zone-backend-contract` skill's
guest-bundle convention — no `vx.ip=<cidr>` kernel cmdline, no `vmlinuz`/`initrd.img` split, no
attachment to `GatewayPlan`'s own endpoints. It boots as its own standalone appliance VM (full
disk image, SONiC's own bootloader/init) and receives config the way a real SONiC switch does
(`config_db.json`, `config load` or as the initial `/etc/sonic/config_db.json`), not through
anything vxedge's zone backends provide. Classification: `class=gw`, `subtype=nos`, `layer=os`.

## Not built here — re-labeled from an official source

SONiC-VS is produced by upstream [`sonic-net/sonic-buildimage`](https://github.com/sonic-net/sonic-buildimage)'s
own multi-hour CI pipeline. This part does not compile it — `build.sh` fetches an official
pre-built artifact and stages it for `publish-vm-disk.sh` to push under vxedge's own registry
namespace, digest-pinned. Same third-party re-labeling pattern QNX/AAOS use ("commit recipes
and fetch instructions only," `vxparts/AGENTS.md`).

**Upstream source: resolved 2026-08-03, not `oras pull`-able.** Checked both candidates from
the original request: [sonic.software](https://sonic.software) is an *unofficial* community
index (its own site says so) that mirrors [`bluecmd/sonic-builds`](https://github.com/bluecmd/sonic-builds),
whose `generate.sh` — read directly, not guessed — turns out to query the exact same source
this README now pins directly: `sonic-buildimage`'s own Azure Pipelines build API
(`dev.azure.com/mssonic/build`, public, unauthenticated). There is no OCI/ORAS registry
involved on the upstream side — the artifact is an Azure Pipelines build output. Pinned build:
**`Azure.sonic-buildimage.official.vs`, definition 142, branch `202505`, buildNumber
`20260803.4`**, built from `sonic-buildimage` commit `ff3c0c9f686a1d0dbddbe813b233b3b7a51bd8e2`
— [build page](https://dev.azure.com/mssonic/build/_build/results?buildId=1182664). A specific
build id, not "latest on a branch" (reproducibility, `ARCHITECTURE.md` §13): re-running
`build.sh` fetches the exact same bytes as long as Azure retains that build's artifacts, which
is itself a real constraint worth knowing — these are CI outputs, not versioned GitHub
Releases, and retention is not guaranteed indefinite.

## License

**Confirmed 2026-08-03, not yet a publish decision.** `sonic-buildimage`'s own LICENSE
(`Apache-2.0`, Microsoft) covers the *build tooling*. A separate `ThirdPartyLicenses.txt` in
the same repo (~67KB — a real, substantial manifest, not a formality) covers every packaged
component actually bundled *into* a built image, under their own upstream terms. `part.yaml`'s
`license:` states both facts; it is not a legal clearance to redistribute the built artifact —
get that confirmed by whoever owns that call before first publish, the same diligence already
applied to Open5GS/UERANSIM (AGPL-3.0) and AAOS (trademark/CTS constraints) in
`docs/TASKS.md`'s licensing review.

## Build

```
./build.sh [out-dir]     # default: ./bundle; AZURE_BUILD_ID=<id> to override the pin
```

Needs: `curl`, `gunzip`. Resolves the pinned Azure build's current download URL (Azure's
artifact download links are per-request tokens, not stable — re-resolved from the build id
every run, not hardcoded), downloads `sonic-vs.img.gz` (~1.9GB compressed), decompresses it,
computes its SHA256, and writes a digest-stamped `meta.json` alongside it (adds `org.vxedge.*`
classification fields, same shape `linux-probe`'s bundle uses).

**Do not boot the staged `bundle/sonic-vs.img` before publishing.** QEMU opens a qcow2
read-write by default, and SONiC's own first-boot sequence writes to the disk (removes its own
first-boot marker file, writes logs, ...) — found live 2026-08-03: a boot smoke-test silently
changed the staged image's sha256 out from under its own `meta.json`. Boot a *copy* to verify a
build, or re-run `build.sh` again afterward before publishing.

## Verified locally, 2026-08-03

Downloaded (build 1182664, ~1.9GB compressed), `gzip -t` clean, decompressed to a valid QEMU
QCOW2 v3 image (16GiB virtual, 6.01GiB actual, SHA256
`0a95ffa745e8e9871653d8605f372a2761edcef2ec53844a37651e343be7dda5` — matches `part.yaml`'s
pinned `upstream.digest`). A disposable copy (not the published bytes) booted clean under
QEMU/KVM: GRUB → `SONiC-OS-202505.1182664-ff3c0c9f6` → login prompt in under 10s of kernel
time, no errors in the boot log. Logged in interactively (`admin`/`YourPaSsWoRd`, SONiC's
default) and ran `show version`:

```
SONiC Software Version: SONiC.202505.1182664-ff3c0c9f6
Platform: x86_64-kvm_x86_64-r0
ASIC: vs
```

— exactly the pinned build, and every expected container present (`docker-orchagent` — SWSS,
the process that actually consumes `config_db.json`'s `VLAN`/`VLAN_MEMBER` tables —
`docker-syncd-vs`, `docker-database`, `docker-fpm-frr`, ...). This confirms the artifact itself
is genuine and usable; it does not yet confirm config parity (see below).

## Publish

```
../../../../../scripts/publish/publish-vm-disk.sh ./bundle ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:<semver>
```

`publish-vm-disk.sh` is the sibling of `publish-vm-bundle.sh` (kernel+initrd zone guests) for
parts that ship as one complete disk image instead — SONiC-VS today, any future full-appliance
VM twin later.

**Published 2026-08-03**: `ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:202505.1182664`. Confirmed
via `oras manifest fetch` (not just a successful push exit code): the pushed
`sonic-vs.img` layer's digest, size (6457589760 bytes), and every `org.vxedge.*` annotation
match the local `bundle/meta.json` exactly.

## What this part does not include

The local boot verification above proves the artifact is genuine and boots correctly — it does
not verify config parity against `vxedge_core::sonic`'s rendered `config_db.json`, which is the
other half of `docs/TASKS.md` #16's SONiC-VS item and remains tracked separately: pushing a
rendered config into a running instance (`config load`) and reading it back
(`show vlan brief`/`redis-cli`) to confirm it matches what the renderer produced.
