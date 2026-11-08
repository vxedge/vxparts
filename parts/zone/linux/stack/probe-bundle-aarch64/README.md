# parts/zone/linux/stack/probe-bundle-aarch64

The aarch64 build of [`probe-bundle`](../probe-bundle): the same `linux-probe` guest (a minimal busybox
initramfs that autostarts a static `vxprobe` reflector), for the instruction set of production zone ECUs.
It is a separate part because each instruction set is its own image: a result names the one it ran on.

**Classification**: `class=zone`, `subtype=linux`, `layer=stack`, `arch=aarch64`.

**Guest contract** (`zone-backend-contract` skill), as `probe-bundle`: kernel cmdline `vx.ip=<cidr>`
configures `eth0`, and the payload (`vxprobe reflect` on `0.0.0.0:9800`) starts as PID 1's child. The console
is the PL011, `ttyAMA0`. `meta.json` names `"arch": "aarch64"`, which is how vxedge's `qemu-microvm` knows to
boot it on QEMU's `virt` machine.

**Backend:** `qemu-microvm` with aarch64 support (vxedge #106). On an arm64 host it runs under KVM; anywhere
else under QEMU's emulator (TCG), and vxedge reports `acceleration: tcg`. A TCG run is functional evidence
only, never timed.

## Inputs, all pinned

| Input | Pin |
|---|---|
| Kernel | Ubuntu 26.04 `linux-image-unsigned-7.0.0-14-generic` arm64, `.deb` sha256 `03dc4ef5…` |
| busybox | Ubuntu 26.04 `busybox-static` 1.37.0-7ubuntu1 arm64, `.deb` sha256 `fcf50794…` |
| vxprobe | the vxagents checkout's commit, static `aarch64-unknown-linux-musl`, recorded in `meta.json` |

Unlike `probe-bundle`, which copies the host's own kernel, nothing here depends on the build host: two builds
from the same inputs are byte-identical, so a vehicle can pin this part by digest.

Ubuntu ships the arm64 kernel as an EFI zboot image with a zstd payload, which QEMU's `-kernel` does not load.
`build.sh` unwraps it to the plain `Image`, using the payload offset and size from the zboot header. The
kernel has virtio-mmio, virtio-net, the PL011 console and devtmpfs built in, so the initramfs needs no modules.

## Build

```
./build.sh [out-dir]     # default: ./bundle
```

Needs `curl`, `dpkg-deb`, `zstd`, `python3`, `cpio`, and rustup (it adds the `aarch64-unknown-linux-musl`
target; the linker is `rust-lld`). vxprobe is built from the sibling `vxagents` checkout, or from
`VXAGENTS=<path>`. The output is gitignored.

## Local boot check (unprivileged)

```
qemu-system-aarch64 -M virt -cpu cortex-a57 -m 256m -nographic -nodefaults -no-user-config \
  -global virtio-mmio.force-legacy=false -serial stdio -kernel bundle/vmlinuz -initrd bundle/initrd.img \
  -append 'console=ttyAMA0 vx.ip=10.0.2.15/24' \
  -netdev user,id=n0,hostfwd=udp:127.0.0.1:19800-:9800 -device virtio-net-device,netdev=n0
```

Verified 2026-11-08 on an x86_64 host under TCG: it booted and answered 20 of 20 UDP probes on `:9800`.

## Publish

Not published yet. To publish:

```
../../../../../scripts/publish/publish-vm-bundle.sh ./bundle ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle-aarch64:<semver>
```
