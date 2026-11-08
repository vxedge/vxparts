#!/usr/bin/env bash
# Build the aarch64 `linux-probe` guest bundle: Ubuntu's arm64 kernel and a minimal busybox
# initramfs that autostarts a static vxprobe reflector. Boots under qemu-microvm's aarch64 path
# (`qemu-system-aarch64 -M virt`, in the vxedge release after 0.9.1), under KVM on an arm64 host and under TCG
# anywhere else.
#
# Usage:  ./build.sh [out-dir]     (default ./bundle)
# Needs:  curl, dpkg-deb, zstd, python3, cpio; rustup with the aarch64-unknown-linux-musl target
#         (added automatically); the sibling vxagents checkout, or VXAGENTS=<path>.
#
# Guest contract: as probe-bundle. Kernel cmdline `vx.ip=<cidr>` configures eth0, and the payload
# (vxprobe reflect on 0.0.0.0:9800) starts as PID-1 child. Console: ttyAMA0.
#
# Every input is pinned: the two Ubuntu packages by sha256 (from the ports archive index), vxprobe
# by the vxagents commit. Two builds from the same inputs are byte-identical.
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"
WS="$(dirname "$VXPARTS_ROOT")"
VXAGENTS="${VXAGENTS:-$WS/vxagents}"   # the vxagents checkout vxprobe is built from
PORTS=http://ports.ubuntu.com/ubuntu-ports
KVER=7.0.0-14-generic
DEBS=(
  "pool/main/l/linux/linux-image-unsigned-7.0.0-14-generic_7.0.0-14.14_arm64.deb 03dc4ef52553617ee61b999b43d36a393044ae3ef226e2c793e5d8bb4f301d3d"
  "pool/main/b/busybox/busybox-static_1.37.0-7ubuntu1_arm64.deb fcf50794faf920455895d7ef103d1c54b9ebf7f18d2e52982dbf3903b7769592"
)

for tool in curl dpkg-deb zstd python3 cpio; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== fetching and verifying the pinned Ubuntu arm64 packages"
for entry in "${DEBS[@]}"; do
  read -r path sha <<<"$entry"
  deb="$WORK/$(basename "$path")"
  curl -fsSL --retry 3 -o "$deb" "$PORTS/$path"
  echo "$sha  $deb" | sha256sum -c --quiet -
  dpkg-deb -x "$deb" "$WORK/root"
done

# Ubuntu ships the arm64 kernel as an EFI zboot image with a zstd payload, which QEMU's -kernel
# does not load. The plain `Image` is the payload: its offset and size are in the zboot header.
echo "== unwrapping the kernel's zboot container"
python3 -I - "$WORK/root/boot/vmlinuz-$KVER" "$WORK/Image.zst" <<'PY'
import struct, sys
b = open(sys.argv[1], "rb").read()
if b[4:8] != b"zimg":
    sys.exit("not an EFI zboot image")
off, size = struct.unpack_from("<II", b, 8)
comp = b[0x18:0x20].split(b"\0")[0]
if comp != b"zstd":
    sys.exit(f"zboot payload is {comp!r}, expected zstd")
open(sys.argv[2], "wb").write(b[off:off + size])
PY
zstd -dq "$WORK/Image.zst" -o "$WORK/Image"

echo "== building static vxprobe (aarch64-unknown-linux-musl)"
rustup target add aarch64-unknown-linux-musl >/dev/null 2>&1 || true
( cd "$VXAGENTS" && CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=rust-lld \
    cargo build --release --locked --target aarch64-unknown-linux-musl -p vxprobe )
VXPROBE="$VXAGENTS/target/aarch64-unknown-linux-musl/release/vxprobe"
VXAGENTS_COMMIT="$(git -C "$VXAGENTS" rev-parse HEAD)"

echo "== assembling initramfs"
STAGE="$WORK/stage"
mkdir -p "$STAGE"/{bin,dev,proc,sys,etc}
cp "$WORK/root/usr/bin/busybox" "$STAGE/bin/busybox"
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
# Reproducible initramfs, as probe-bundle: mtimes pinned, member order sorted, no gzip header.
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"
find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
( cd "$STAGE" && find . -print0 | LC_ALL=C sort -z \
    | cpio --null -o -H newc --reproducible 2>/dev/null | gzip -9 -n ) \
  > "$OUT/initrd.img"
cp "$WORK/Image" "$OUT/vmlinuz"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" python3 - "$OUT" "$KVER" "$VXAGENTS_COMMIT" "${DEBS[@]}" <<'EOF2'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = {"bundle": "linux-probe", "arch": "aarch64"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "kernel_version": sys.argv[2],
    "payload": "vxprobe reflect :9800 (static musl)",
    "vxagents_commit": sys.argv[3],
    "sources": [dict(zip(("path", "sha256"), d.split())) for d in sys.argv[4:]],
    "files": {p.name: sha(out / p.name) for p in [out/"vmlinuz", out/"initrd.img"]},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF2

echo "== bundle ready: $OUT (vmlinuz, initrd.img, meta.json)"
echo "== unprivileged boot check:"
echo "   qemu-system-aarch64 -M virt -cpu cortex-a57 -m 256m -nographic -nodefaults -no-user-config \\"
echo "     -serial stdio -kernel $OUT/vmlinuz -initrd $OUT/initrd.img \\"
echo "     -append 'console=ttyAMA0 vx.ip=10.0.0.2/24' -netdev user,id=n0 -device virtio-net-device,netdev=n0"
