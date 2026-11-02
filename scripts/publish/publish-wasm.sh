#!/usr/bin/env bash
# Push a WebAssembly capsule (<name>.wasm + meta.json) to the vxparts OCI registry via ORAS,
# stamping org.vxedge.* annotations read from its own meta.json.
#
# Usage:  ./publish-wasm.sh <bundle-dir> <ref>
#   e.g.  ./publish-wasm.sh parts/zone/wasm/app/reflector-capsule/bundle \
#           ghcr.io/vxedge/parts/zone/wasm/app/reflector-capsule:0.1.0
set -euo pipefail

BUNDLE="${1:?usage: $0 <bundle-dir> <ref>}"
REF="${2:?usage: $0 <bundle-dir> <ref>}"

command -v oras >/dev/null || { echo "error: oras CLI not found — see https://oras.land" >&2; exit 1; }
META="$BUNDLE/meta.json"
[[ -f "$META" ]] || { echo "error: $META not found — run this part's build.sh first" >&2; exit 1; }

mapfile -t WASM < <(cd "$BUNDLE" && find . -maxdepth 1 -name '*.wasm' -printf '%P\n')
[[ ${#WASM[@]} -eq 1 ]] || {
  echo "error: $BUNDLE must hold exactly one .wasm file, found ${#WASM[@]}" >&2; exit 1; }

mapfile -t ANN_ARGS < <(python3 -c "
import json
for k, v in sorted(json.load(open('$META')).items()):
    if k.startswith('org.vxedge.'):
        print('--annotation'); print(f'{k}={v}')
")
[[ ${#ANN_ARGS[@]} -gt 0 ]] || {
  echo "error: $META declares no org.vxedge.* classification keys" >&2; exit 1; }

echo "== pushing $BUNDLE -> $REF"
# Pushed from inside the bundle dir so the build host's layout stays out of the artifact.
( cd "$BUNDLE" && oras push "$REF" \
    --artifact-type "application/vnd.vxedge.part.v1" "${ANN_ARGS[@]}" \
    "${WASM[0]}:application/wasm" \
    "meta.json:application/vnd.vxedge.part.meta+json" )

echo "== verifying pull round-trip"
PULLDIR="$(mktemp -d)"
trap 'rm -rf "$PULLDIR"' EXIT
oras pull "$REF" -o "$PULLDIR"
for f in "${WASM[0]}" meta.json; do
  cmp -s "$BUNDLE/$f" "$PULLDIR/$f" || { echo "error: $f differs after round-trip" >&2; exit 1; }
done
echo "== round-trip OK: $REF"
