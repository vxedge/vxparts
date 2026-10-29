#!/usr/bin/env bash
# Build the `linux-probe` guest bundle: host kernel + minimal busybox initramfs
# that autostarts a static vxprobe reflector. Boots under both zone VM
# backends (qemu-microvm direct kernel boot, libvirt direct kernel boot).
#
# Usage:  ./build.sh [out-dir]     (default ./bundle)
# Needs:  busybox-static (apt install busybox-static), rustup musl target
#         (added automatically), readable /boot/vmlinuz-$(uname -r).
#
# Guest contract: kernel cmdline `vx.ip=<cidr>` configures eth0; the payload
# (vxprobe reflect on 0.0.0.0:9800) starts as PID-1 child. Serial console
# carries logs. Bundle files are digest-recorded in meta.json.
#
# Migrated from zones-legacy/scripts/build-guest-bundle.sh (Track P, 2026-07-26).
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"
WS="$(dirname "$VXPARTS_ROOT")"

# KVER labels the bundle in meta.json. It defaults to the running kernel because the
# default KERNEL is the running kernel's image — override BOTH together, or meta.json
# will misreport which kernel is actually in the bundle (digest-recorded, §13).
KVER="${KVER:-$(uname -r)}"
KERNEL="${KERNEL:-/boot/vmlinuz-$KVER}"
if [[ ! -r "$KERNEL" ]]; then
  echo "error: $KERNEL not readable — on Ubuntu:  sudo chmod 644 $KERNEL" >&2
  echo "       (or copy it somewhere readable and set KERNEL=/path/to/vmlinuz)" >&2
  exit 1
fi

BUSYBOX="$(command -v busybox || true)"
if [[ -z "$BUSYBOX" ]]; then
  echo "error: busybox not found —  sudo apt install busybox-static" >&2
  exit 1
fi
if ! file -b "$BUSYBOX" | grep -q "statically linked"; then
  echo "error: $BUSYBOX is not static —  sudo apt install busybox-static" >&2
  exit 1
fi

# Static vxprobe (musl) — pure-Rust deps, links with rustup's bundled musl.
echo "== building static vxprobe (x86_64-unknown-linux-musl)"
rustup target add x86_64-unknown-linux-musl >/dev/null 2>&1 || true
( cd "$WS/vxagents" && cargo build --release --target x86_64-unknown-linux-musl -p vxprobe )
VXPROBE="$WS/vxagents/target/x86_64-unknown-linux-musl/release/vxprobe"
file -b "$VXPROBE" | grep -Eq "statically linked|static-pie linked" || {
  echo "error: vxprobe did not link statically" >&2; exit 1; }

echo "== assembling initramfs"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE"/{bin,dev,proc,sys,etc}
cp "$BUSYBOX" "$STAGE/bin/busybox"
cp "$VXPROBE" "$STAGE/bin/vxprobe"
for app in sh ip mount sleep cat grep; do ln -s busybox "$STAGE/bin/$app"; done

cat > "$STAGE/init" <<'INIT'
#!/bin/sh
# vxparts linux-probe guest init: network from cmdline, then the payload.
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sys /sys
/bin/mount -t devtmpfs dev /dev 2>/dev/null

CIDR=""
for tok in $(cat /proc/cmdline); do
  case "$tok" in vx.ip=*) CIDR="${tok#vx.ip=}";; esac
done
/bin/ip link set lo up
if [ -n "$CIDR" ]; then
  /bin/ip addr add "$CIDR" dev eth0
fi
/bin/ip link set eth0 up
echo "vxparts guest up: eth0=$CIDR — starting vxprobe reflector :9800"
exec /bin/vxprobe reflect --listen 0.0.0.0:9800
INIT
chmod +x "$STAGE/init"

mkdir -p "$OUT"
# Reproducible initramfs: cpio embeds each file's mtime and gzip embeds a build timestamp, so
# without normalizing both, the same inputs produce a different sha256 on every run — which
# would make the digests recorded below identify a build rather than its inputs (§13). Pin
# mtimes to SOURCE_DATE_EPOCH, sort the member order, and drop gzip's timestamp/name header.
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"
find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
( cd "$STAGE" && find . -print0 | LC_ALL=C sort -z \
    | cpio --null -o -H newc --reproducible 2>/dev/null | gzip -9 -n ) \
  > "$OUT/initrd.img"
cp "$KERNEL" "$OUT/vmlinuz"

# Classification comes from `vxpn.py meta`: identity from this part's own path, declared
# metadata from its part.yaml. Nothing about the part is restated in this recipe, so a
# licence or annotation change is a one-line edit to part.yaml and never a code change.
VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"

VX_META="$VX_META" python3 - "$OUT" "$KVER" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = {"bundle": "linux-probe"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "kernel_version": sys.argv[2],
    "payload": "vxprobe reflect :9800 (static musl)",
    "files": {p.name: sha(out / p.name) for p in [out/"vmlinuz", out/"initrd.img"]},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF

echo "== bundle ready: $OUT (vmlinuz, initrd.img, meta.json)"
echo "== unprivileged boot check:"
echo "   qemu-system-x86_64 -M microvm,acpi=off -m 128m -nographic -nodefaults -no-user-config \\"
echo "     -serial stdio -kernel $OUT/vmlinuz -initrd $OUT/initrd.img \\"
echo "     -append 'console=ttyS0 vx.ip=10.0.0.2/24' -netdev user,id=n0 -device virtio-net-device,netdev=n0"
