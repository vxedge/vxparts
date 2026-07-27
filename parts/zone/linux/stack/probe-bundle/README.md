# parts/zone/linux/stack/probe-bundle

Migrated from `vxzones/scripts/build-guest-bundle.sh` (2026-07-26, Track P). The
`linux-probe` guest bundle: host kernel + minimal busybox initramfs that autostarts a static
`vxprobe` reflector. Boots under both zone VM backends (qemu-microvm direct kernel boot,
libvirt direct kernel boot). Used by exp-002/exp-002b's microvm and libvirt arms; proved the
boot-under-vxedge contract for both VM backends (H3 numbers were measured on this bundle).

**Classification**: `class=zone`, `subtype=linux`, `layer=stack` (composite: kernel + initrd,
no separate os/middleware split for this minimal probe payload).

**Guest contract** (`zone-backend-contract` skill): kernel cmdline `vx.ip=<cidr>` configures
`eth0`; the payload (`vxprobe reflect` on `0.0.0.0:9800`) starts as PID-1 child. Serial console
carries logs. Bundle files are digest-recorded in `meta.json`.

## Build

```
./build.sh [out-dir]     # default: ./bundle
```

Needs: `busybox-static` (`apt install busybox-static`), rustup musl target (added
automatically), a readable `/boot/vmlinuz-$(uname -r)`. Builds a static-musl `vxprobe` from
the sibling `vxagents` repo.

Output (`bundle/` by default) is gitignored — host-generated, not committed. It contains
`vmlinuz`, `initrd.img`, and a digest-stamped `meta.json` (adds `org.vxedge.*` classification
fields alongside the existing `bundle`/`kernel_version`/`payload`/`files` keys).

## Publish

Not yet published anywhere — `oras` CLI is not installed on the build host yet (see
`../../../../../scripts/publish/README.md`). Once installed:

```
../../../../../scripts/publish/publish-vm-bundle.sh ./bundle ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle:<semver>
```

## Local boot check (unprivileged)

```
qemu-system-x86_64 -M microvm,acpi=off -m 128m -nographic -nodefaults -no-user-config \
  -serial stdio -kernel bundle/vmlinuz -initrd bundle/initrd.img \
  -append 'console=ttyS0 vx.ip=10.0.0.2/24' -netdev user,id=n0 -device virtio-net-device,netdev=n0
```
