#!/usr/bin/env bash
# Build the FreeRTOS probe guest bundle: a Multiboot ELF that echoes UDP on :9800, as
# `vxprobe reflect` does, for vxedge's qemu-microvm backend.
#
#   ./build.sh [out-dir]       # default: ./bundle
#
# Nothing but Podman is needed on the host. The build runs in Debian bookworm pinned by digest,
# with its compiler installed from snapshot.debian.org at a fixed date, against FreeRTOS-Kernel
# and FreeRTOS-Plus-TCP checked out at pinned commits; the script refuses a checkout that is not
# that commit. Output: vmlinuz (the ELF), an empty initrd.img (the bundle contract names the file;
# a Multiboot kernel has no use for it) and meta.json.
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "${1:-$PART_DIR/bundle}")"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"

BASE_IMAGE="docker.io/library/debian@sha256:63a496b5d3b99214b39f5ed70eb71a61e590a77979c79cbee4faf991f8c0783e"
SNAPSHOT="20261101T000000Z"
KERNEL_TAG="V11.2.0"
KERNEL_SHA="0adc196d4bd52a2d91102b525b0aafc1e14a2386"
TCP_TAG="V4.4.2"
TCP_SHA="b86ad086e9870099bb0ac18a75dcb7f6dd508cc7"

command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== building in $BASE_IMAGE (apt from snapshot $SNAPSHOT)"
podman run --rm -v "$WORK:/ws:Z" -v "$PART_DIR/app:/app:ro,Z" -w /ws "$BASE_IMAGE" bash -euo pipefail -c "
    rm -f /etc/apt/sources.list.d/debian.sources
    echo 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT bookworm main' > /etc/apt/sources.list
    apt-get -qq update >/dev/null
    apt-get -qq install -y --no-install-recommends gcc gcc-multilib binutils make git ca-certificates >/dev/null
    git clone -q --depth 1 --branch $KERNEL_TAG https://github.com/FreeRTOS/FreeRTOS-Kernel.git kernel
    git clone -q --depth 1 --branch $TCP_TAG https://github.com/FreeRTOS/FreeRTOS-Plus-TCP.git tcp
    for r in 'kernel $KERNEL_SHA' 'tcp $TCP_SHA'; do
        set -- \$r
        got=\$(git -C \$1 rev-parse HEAD)
        [ \"\$got\" = \$2 ] || { echo \"error: \$1 is \$got, expected \$2\" >&2; exit 1; }
    done
    cp -r /app build
    make -s -C build K=/ws/kernel T=/ws/tcp kernel.elf
    gcc --version | head -1 > toolchain.txt
    ld --version | head -1 >> toolchain.txt
    chmod -R a+rwX /ws
  "

cp "$WORK/build/kernel.elf" "$OUT/vmlinuz"
: > "$OUT/initrd.img"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" BASE_IMAGE="$BASE_IMAGE" SNAPSHOT="$SNAPSHOT" KERNEL_TAG="$KERNEL_TAG" KERNEL_SHA="$KERNEL_SHA" \
TCP_TAG="$TCP_TAG" TCP_SHA="$TCP_SHA" TOOLCHAIN="$(cat "$WORK/toolchain.txt")" \
python3 - "$OUT" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
e = os.environ
meta = {"bundle": "freertos-probe"}
meta.update(json.loads(e["VX_META"]))
meta.update({
    "kernel_version": "freertos-" + e["KERNEL_TAG"].lstrip("V"),
    "format": "multiboot-elf32",
    "payload": "UDP echo on :9800 (FreeRTOS-Plus-TCP " + e["TCP_TAG"] + ")",
    "freertos_kernel_commit": e["KERNEL_SHA"],
    "freertos_plus_tcp_commit": e["TCP_SHA"],
    "build_image": e["BASE_IMAGE"],
    "apt_snapshot": e["SNAPSHOT"],
    "toolchain": e["TOOLCHAIN"].splitlines(),
    "files": {n: sha(out / n) for n in ("vmlinuz", "initrd.img")},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF
echo "== bundle ready: $OUT (vmlinuz, initrd.img, meta.json)"
