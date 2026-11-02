#!/usr/bin/env bash
# Build the reflector capsule: a WASI 0.2 command component for `backend: wasm-capsule`.
#
# Usage:  ./build.sh [out-dir]     (default ./bundle)
# Needs:  rustup's wasm32-wasip2 target (added automatically).
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"
WASM=reflector-capsule.wasm

rustup target add wasm32-wasip2 >/dev/null 2>&1 || true
# Trimmed paths keep the build host's layout out of the module, so the digest depends on the
# source and the toolchain alone.
( cd "$PART_DIR" && RUSTFLAGS="--remap-path-prefix=$PART_DIR=." \
  CARGO_TARGET_DIR="$PART_DIR/target" cargo build --release --locked --target wasm32-wasip2 )

mkdir -p "$OUT"
cp "$PART_DIR/target/wasm32-wasip2/release/$WASM" "$OUT/$WASM"

VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"
VX_META="$VX_META" python3 - "$OUT" "$WASM" <<'PY'
import hashlib, json, os, pathlib, sys
out, wasm = pathlib.Path(sys.argv[1]), sys.argv[2]
meta = {"bundle": "reflector-capsule"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "payload": "UDP reflector on :9800",
    "files": {wasm: hashlib.sha256((out / wasm).read_bytes()).hexdigest()},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
PY
echo "== capsule ready: $OUT"
