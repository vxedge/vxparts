#!/usr/bin/env bash
# Build the Zephyr probe firmware for QEMU's mps2-an385 (Cortex-M3): an ELF that echoes UDP on
# :9800, as `vxprobe reflect` does, for vxedge's qemu-mcu backend.
#
#   ./build.sh [out-dir]       # default: ./bundle
#
# Nothing but Podman is needed on the host. The build runs in Debian trixie pinned by digest,
# with its Arm compiler and Zephyr's host tools installed from snapshot.debian.org at a fixed
# date, against Zephyr and the two CMSIS modules it needs checked out at pinned commits; the
# script refuses a checkout that is not that commit. No west: the modules are named directly.
# Output: firmware.elf and meta.json.
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "${1:-$PART_DIR/bundle}")"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"

BASE_IMAGE="docker.io/library/debian@sha256:9c6e381421d0f48d1b8133e573f33c185ee16cbf505eda9c4a8a4791b25ea8a6"
SNAPSHOT="20261101T000000Z"
ZEPHYR_TAG="v4.5.0"
ZEPHYR_SHA="41d10b59730406bbab4ca9f1fbbe9e96aafb4966"
# The revisions Zephyr's own west.yml pins at $ZEPHYR_TAG.
CMSIS_SHA="512cc7e895e8491696b61f7ba8066b4a182569b8"
CMSIS6_SHA="1c1840af7a7e757d6e2fec3ddb0e5ce0dfcc93c8"

command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "== building in $BASE_IMAGE (apt from snapshot $SNAPSHOT)"
podman run --rm -v "$WORK:/ws:Z" -v "$PART_DIR/app:/app:ro,Z" -w /ws "$BASE_IMAGE" bash -euo pipefail -c "
    rm -f /etc/apt/sources.list.d/debian.sources
    echo 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT trixie main' > /etc/apt/sources.list
    apt-get -qq update >/dev/null
    apt-get -qq install -y --no-install-recommends gcc-arm-none-eabi libnewlib-arm-none-eabi git ca-certificates \
        cmake ninja-build device-tree-compiler python3 python3-pyelftools python3-yaml python3-packaging \
        python3-pykwalify python3-jsonschema file >/dev/null
    # Clones retry: a fetch that fails midway starts again from an empty directory.
    retry() { d=\$1; shift; for i in 1 2 3 4 5 6; do rm -rf \$d; \"\$@\" && return 0; echo \"retry \$i: \$d\" >&2; sleep 20; done; return 1; }
    export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=http.lowSpeedLimit GIT_CONFIG_VALUE_0=1000 GIT_CONFIG_KEY_1=http.lowSpeedTime GIT_CONFIG_VALUE_1=60
    retry zephyr git clone -q --depth 1 --branch $ZEPHYR_TAG https://github.com/zephyrproject-rtos/zephyr.git zephyr
    fetch() { git init -q \$1 && git -C \$1 fetch -q --depth 1 \$2 \$3 && git -C \$1 checkout -q FETCH_HEAD; }
    retry cmsis fetch cmsis https://github.com/zephyrproject-rtos/cmsis.git $CMSIS_SHA
    retry cmsis_6 fetch cmsis_6 https://github.com/zephyrproject-rtos/CMSIS_6.git $CMSIS6_SHA
    for r in 'zephyr $ZEPHYR_SHA' 'cmsis $CMSIS_SHA' 'cmsis_6 $CMSIS6_SHA'; do
        set -- \$r
        got=\$(git -C \$1 rev-parse HEAD)
        [ \"\$got\" = \$2 ] || { echo \"error: \$1 is \$got, expected \$2\" >&2; exit 1; }
    done
    export ZEPHYR_BASE=/ws/zephyr ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb GNUARMEMB_TOOLCHAIN_PATH=/usr
    cmake -GNinja -S /app -B build -DBOARD=mps2/an385 -DZEPHYR_MODULES='/ws/cmsis;/ws/cmsis_6' >/dev/null
    ninja -C build >/dev/null
    arm-none-eabi-gcc --version | head -1 > toolchain.txt
    arm-none-eabi-ld --version | head -1 >> toolchain.txt
    chmod -R a+rwX /ws
  "

cp "$WORK/build/zephyr/zephyr.elf" "$OUT/firmware.elf"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" BASE_IMAGE="$BASE_IMAGE" SNAPSHOT="$SNAPSHOT" ZEPHYR_TAG="$ZEPHYR_TAG" ZEPHYR_SHA="$ZEPHYR_SHA" \
CMSIS_SHA="$CMSIS_SHA" CMSIS6_SHA="$CMSIS6_SHA" TOOLCHAIN="$(cat "$WORK/toolchain.txt")" \
python3 - "$OUT" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
e = os.environ
meta = {"bundle": "zephyr-probe-mps2"}
meta.update(json.loads(e["VX_META"]))
meta.update({
    "kernel_version": "zephyr-" + e["ZEPHYR_TAG"].lstrip("v"),
    "format": "elf32-arm",
    "payload": "UDP echo on :9800 (Zephyr sockets)",
    "zephyr_commit": e["ZEPHYR_SHA"],
    "cmsis_commit": e["CMSIS_SHA"],
    "cmsis_6_commit": e["CMSIS6_SHA"],
    "build_image": e["BASE_IMAGE"],
    "apt_snapshot": e["SNAPSHOT"],
    "toolchain": e["TOOLCHAIN"].splitlines(),
    "files": {"firmware.elf": sha(out / "firmware.elf")},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF
echo "== bundle ready: $OUT (firmware.elf, meta.json)"
