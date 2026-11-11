#!/usr/bin/env bash
# Build the FreeRTOS probe firmware for QEMU's mps2-an385 (Cortex-M3): an ELF that echoes UDP
# on :9800, as `vxprobe reflect` does, for vxedge's qemu-mcu backend.
#
#   ./build.sh [out-dir]       # default: ./bundle
#
# Nothing but Podman is needed on the host. The build runs in Debian bookworm pinned by digest,
# with its compiler installed from snapshot.debian.org at a fixed date, against FreeRTOS-Kernel,
# FreeRTOS-Plus-TCP checked out at pinned commits; the script refuses a checkout that is not that
# commit. The board files of FreeRTOS's mps2 echo demo are fetched at a pinned commit and checked
# against demo.sha256. patches/ is applied to FreeRTOS-Plus-TCP before the build.
# Output: firmware.elf and meta.json.
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
DEMO_TAG="202411.00"
DEMO_SHA="152cf36d6775bce6026a791845af12201aae703d"
DEMO_RAW="https://raw.githubusercontent.com/FreeRTOS/FreeRTOS/$DEMO_SHA/FreeRTOS-Plus/Demo/FreeRTOS_Plus_TCP_Echo_Qemu_mps2"

command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== building in $BASE_IMAGE (apt from snapshot $SNAPSHOT)"
podman run --rm -v "$WORK:/ws:Z" -v "$PART_DIR/app:/app:ro,Z" -v "$PART_DIR/patches:/patches:ro,Z" -v "$PART_DIR/demo.sha256:/part/demo.sha256:ro,Z" -w /ws \
  "$BASE_IMAGE" bash -euo pipefail -c "
    rm -f /etc/apt/sources.list.d/debian.sources
    echo 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT bookworm main' > /etc/apt/sources.list
    apt-get -qq update >/dev/null
    apt-get -qq install -y --no-install-recommends gcc-arm-none-eabi libnewlib-arm-none-eabi make git curl ca-certificates >/dev/null
    # Clones retry: a fetch that fails midway starts again from an empty directory.
    retry() { d=\$1; shift; for i in 1 2 3 4 5 6; do rm -rf \$d; \"\$@\" && return 0; echo \"retry \$i: \$d\" >&2; sleep 20; done; return 1; }
    export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=http.lowSpeedLimit GIT_CONFIG_VALUE_0=1000 GIT_CONFIG_KEY_1=http.lowSpeedTime GIT_CONFIG_VALUE_1=60
    retry kernel git clone -q --depth 1 --branch $KERNEL_TAG https://github.com/FreeRTOS/FreeRTOS-Kernel.git kernel
    retry tcp git clone -q --depth 1 --branch $TCP_TAG https://github.com/FreeRTOS/FreeRTOS-Plus-TCP.git tcp
    # The demo's 11 board files, fetched at the pinned commit and checked against demo.sha256.
    mkdir -p demo/CMSIS
    while read -r sum f; do
        for i in 1 2 3 4 5 6; do
            curl -sSf --retry 3 -m 60 -o demo/\$f $DEMO_RAW/\$f && break
            echo \"retry \$i: \$f\" >&2; sleep 10
        done
    done < /part/demo.sha256
    (cd demo && sha256sum --quiet -c /part/demo.sha256)
    for r in 'kernel $KERNEL_SHA' 'tcp $TCP_SHA'; do
        set -- \$r
        got=\$(git -C \$1 rev-parse HEAD)
        [ \"\$got\" = \$2 ] || { echo \"error: \$1 is \$got, expected \$2\" >&2; exit 1; }
    done
    for p in /patches/*.patch; do git -C tcp apply \"\$p\"; done
    cp -r /app build
    make -s -C build K=/ws/kernel T=/ws/tcp D=/ws/demo firmware.elf >/dev/null
    arm-none-eabi-gcc --version | head -1 > toolchain.txt
    arm-none-eabi-ld --version | head -1 >> toolchain.txt
    chmod -R a+rwX /ws
  "

cp "$WORK/build/firmware.elf" "$OUT/firmware.elf"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" BASE_IMAGE="$BASE_IMAGE" SNAPSHOT="$SNAPSHOT" KERNEL_TAG="$KERNEL_TAG" KERNEL_SHA="$KERNEL_SHA" \
TCP_TAG="$TCP_TAG" TCP_SHA="$TCP_SHA" DEMO_TAG="$DEMO_TAG" DEMO_SHA="$DEMO_SHA" PATCHES="$PART_DIR/patches" \
TOOLCHAIN="$(cat "$WORK/toolchain.txt")" python3 - "$OUT" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
e = os.environ
meta = {"bundle": "freertos-probe-mps2"}
meta.update(json.loads(e["VX_META"]))
meta.update({
    "kernel_version": "freertos-" + e["KERNEL_TAG"].lstrip("V"),
    "format": "elf32-arm",
    "payload": "UDP echo on :9800 (FreeRTOS-Plus-TCP " + e["TCP_TAG"] + ")",
    "freertos_kernel_commit": e["KERNEL_SHA"],
    "freertos_plus_tcp_commit": e["TCP_SHA"],
    "freertos_demo_commit": e["DEMO_SHA"],
    "patches": {p.name: sha(p) for p in sorted(pathlib.Path(e["PATCHES"]).glob("*.patch"))},
    "build_image": e["BASE_IMAGE"],
    "apt_snapshot": e["SNAPSHOT"],
    "toolchain": e["TOOLCHAIN"].splitlines(),
    "files": {"firmware.elf": sha(out / "firmware.elf")},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF
echo "== bundle ready: $OUT (firmware.elf, meta.json)"
