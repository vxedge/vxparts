#!/usr/bin/env bash
# Fetch AGL's own Vimba 22.0.1 qemuarm64 build of the Qt IVI demo, verify it, and lay it out as a
# vxedge root-disk bundle: vmlinuz, rootfs.img, meta.json.
#
# Usage:  ./build.sh [out-dir]     (default ./bundle)
# Needs:  curl, xz, sha256sum. Downloads about 750 MB and writes about 5.8 GB.
#
# AGL publishes no checksums beside these images, so SHA256SUMS pins the files as downloaded from
# AGL's release server on 2026-11-21, by their timestamped names, never `latest/`. Nothing is
# changed: rootfs.img is AGL's ext4 image, decompressed, and its sha256 is pinned too.
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
BASE=https://download.automotivelinux.org/AGL/release/vimba/22.0.1/qemuarm64/deploy/images/qemuarm64
KERNEL='Image--6.18.52+git0+2184786cc3_364c4b44ab-r0.2-qemuarm64-20261027161919.bin'
ROOTFS=agl-ivi-demo-qt-qemuarm64-20261028160403.ext4.xz

for tool in curl xz sha256sum; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found" >&2; exit 1; }
done

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== fetching AGL 22.0.1 (vimba) qemuarm64"
curl -fsSL -o "$WORK/$KERNEL" "$BASE/${KERNEL//+/%2B}"
curl -fsSL -o "$WORK/$ROOTFS" "$BASE/$ROOTFS"
(cd "$WORK" && grep -F -e "$KERNEL" -e "$ROOTFS" "$PART_DIR/SHA256SUMS" | sha256sum --quiet -c -)

echo "== laying out the bundle in $OUT"
install -m 0644 "$WORK/$KERNEL" "$OUT/vmlinuz"
xz -dc -T0 "$WORK/$ROOTFS" > "$OUT/rootfs.img"
(cd "$OUT" && grep -F rootfs.img "$PART_DIR/SHA256SUMS" | sha256sum --quiet -c -)
# AGL's own QEMU settings (qemuboot.conf): four cortex-a57 CPUs and 2 GiB.
printf '%s\n' '{"arch": "aarch64", "cpus": 4, "memory_mb": 2048}' > "$OUT/meta.json"
rm -f "$OUT/initrd.img"
echo "built $OUT: AGL 22.0.1 (vimba) agl-ivi-demo-qt, qemuarm64"
