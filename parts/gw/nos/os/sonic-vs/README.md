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
own multi-hour CI pipeline. This part does not compile it — `build.sh` is a **pull-and-republish
recipe**: `oras pull` the official pre-built image, `oras push` it back under vxedge's own
registry namespace, digest-pinned. Same pattern QNX/AAOS use for other third-party-licensed
guest images ("commit recipes and fetch instructions only," `vxparts/AGENTS.md`).

**Upstream source: pending confirmation.** `part.yaml`'s `upstream.ref`/`upstream.digest` are
placeholders (`TODO-...`) until the exact official registry ref is confirmed — [sonic.software](https://sonic.software)
is a candidate distribution point, alongside whatever `sonic-buildimage`'s own CI publishes.
Do not guess a ref into `part.yaml` or `build.sh`; get it from the upstream project directly
and record it here once confirmed, together with how it was found (branch/tag/pipeline run),
since SONiC-VS artifacts are CI build outputs rather than versioned GitHub Releases and may not
be stable/long-lived at a fixed location — that instability is itself worth recording as a
reproducibility caveat once known, not silently assumed away.

## License

**Not yet confirmed — `part.yaml`'s `license:` field is a placeholder, do not publish with it
still in place.** SONiC itself is an Apache-2.0 Linux Foundation project, but a built VS image
bundles the Debian base and every packaged component under their own upstream licenses —
asserting "Apache-2.0" for the whole artifact would misstate what's actually being
redistributed. Confirm the actual redistribution terms for the specific upstream artifact
before publishing, the same diligence already applied to Open5GS/UERANSIM (AGPL-3.0) and AAOS
(trademark/CTS constraints) in `docs/TASKS.md`'s licensing review.

## Build (once `upstream.ref` is confirmed)

```
UPSTREAM_REF=<registry/repo:tag-or-digest> ./build.sh [out-dir]     # default: ./bundle
```

Needs: the `oras` CLI (<https://oras.land>). Pulls the upstream artifact into `bundle/`,
computes its SHA256, and writes a digest-stamped `meta.json` alongside it (adds `org.vxedge.*`
classification fields, same shape `linux-probe`'s bundle uses).

## Publish

```
../../../../../scripts/publish/publish-vm-disk.sh ./bundle ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:<semver>
```

`publish-vm-disk.sh` is the sibling of `publish-vm-bundle.sh` (kernel+initrd zone guests) for
parts that ship as one complete disk image instead — SONiC-VS today, any future full-appliance
VM twin later.

## What this part does not include

Booting the pushed image and verifying live config parity against `vxedge_core::sonic`'s
rendered `config_db.json` is the other half of `docs/TASKS.md` #16's SONiC-VS item, tracked
separately — this part only gets the image into vxedge's own registry, digest-pinned and
reproducible. Console/SSH automation for that boot-and-verify step is not part of this part.
