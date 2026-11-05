#!/usr/bin/env bash
# Build the Zephyr probe guest bundle: a Multiboot ELF that echoes UDP on :9800, as
# `vxprobe reflect` does, for vxedge's qemu-microvm backend.
#
#   ./build.sh [out-dir]       # default: ./bundle
#
# Nothing but Podman is needed on the host. The build runs in the Zephyr project's CI image,
# pinned by digest, against Zephyr checked out at the pinned commit; the script refuses a
# checkout that is not that commit. Output: vmlinuz (the ELF), an empty initrd.img (the bundle
# contract names the file; a Multiboot kernel has no use for it) and meta.json.
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "${1:-$PART_DIR/bundle}")"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"

CI_IMAGE="ghcr.io/zephyrproject-rtos/ci@sha256:a153979984288133a478adc0bfe1081d2e1c77c2db62e9f9e48a143090913788"
ZEPHYR_TAG="v4.5.0"
ZEPHYR_SHA="41d10b59730406bbab4ca9f1fbbe9e96aafb4966"

command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== building in $CI_IMAGE"
podman run --rm --userns=keep-id --user "$(id -u):$(id -g)" -e HOME=/tmp -e ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-1.0.1 \
  -v "$WORK:/ws:Z" -v "$PART_DIR/app:/app:ro,Z" -w /ws "$CI_IMAGE" bash -euo pipefail -c "
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr $ZEPHYR_TAG . >/dev/null
    west update --narrow -o=--depth=1 zephyr cmsis_6 >/dev/null
    got=\$(git -c safe.directory=/ws/zephyr -C zephyr rev-parse HEAD)
    [ \"\$got\" = $ZEPHYR_SHA ] || { echo \"error: Zephyr is \$got, expected $ZEPHYR_SHA\" >&2; exit 1; }
    west build -p always -b qemu_x86 -d /ws/build /app >/dev/null
  "

cp "$WORK/build/zephyr/zephyr.elf" "$OUT/vmlinuz"
: > "$OUT/initrd.img"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" CI_IMAGE="$CI_IMAGE" ZEPHYR_TAG="$ZEPHYR_TAG" ZEPHYR_SHA="$ZEPHYR_SHA" \
python3 - "$OUT" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = {"bundle": "zephyr-probe"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "kernel_version": "zephyr-" + os.environ["ZEPHYR_TAG"].lstrip("v"),
    "format": "multiboot-elf32",
    "payload": "UDP echo on :9800 (Zephyr sockets)",
    "zephyr_commit": os.environ["ZEPHYR_SHA"],
    "build_image": os.environ["CI_IMAGE"],
    "files": {n: sha(out / n) for n in ("vmlinuz", "initrd.img")},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF
echo "== bundle ready: $OUT (vmlinuz, initrd.img, meta.json)"
