#!/usr/bin/env bash
# Push a zone-class MCU firmware bundle (firmware.elf + meta.json) to the vxparts OCI registry
# via ORAS, stamping org.vxedge.* annotations read from the bundle's own meta.json so
# classification travels with the artifact. vxedge's qemu-mcu backend boots the pulled
# firmware.elf on the board meta.json names (org.vxedge.machine).
#
# Usage:  ./publish-firmware.sh <bundle-dir> <ref>
#   e.g.  ./publish-firmware.sh parts/zone/zephyr/firmware/probe-mps2/bundle \
#           ghcr.io/vxedge/parts/zone/zephyr/firmware/probe-mps2:0.1.0
#
# Requires: oras CLI (https://oras.land).
set -euo pipefail

BUNDLE="${1:?usage: $0 <bundle-dir> <ref>}"
REF="${2:?usage: $0 <bundle-dir> <ref>}"

command -v oras >/dev/null || { echo "error: oras CLI not found — see https://oras.land/docs/installation" >&2; exit 1; }
META="$BUNDLE/meta.json"
[[ -f "$META" ]] || { echo "error: $META not found — run this bundle's build.sh first" >&2; exit 1; }
[[ -f "$BUNDLE/firmware.elf" ]] || { echo "error: $BUNDLE/firmware.elf not found" >&2; exit 1; }

mapfile -t VX_ANNOTATIONS < <(python3 -c "
import json
meta = json.load(open('$META'))
for k, v in sorted(meta.items()):
    if k.startswith('org.vxedge.'):
        print(f'{k}={v}')
")
[[ ${#VX_ANNOTATIONS[@]} -gt 0 ]] || {
  echo "error: $META declares no org.vxedge.* classification keys" >&2; exit 1; }
printf '%s\n' "${VX_ANNOTATIONS[@]}" | grep -q '^org.vxedge.machine=' || {
  echo "error: $META names no org.vxedge.machine; qemu-mcu needs the board" >&2; exit 1; }

ANNOTATIONS=()
for a in "${VX_ANNOTATIONS[@]}"; do ANNOTATIONS+=("--annotation" "$a"); done
echo "== classification: ${VX_ANNOTATIONS[*]}"

echo "== pushing $BUNDLE -> $REF"
# Pushed from inside the bundle dir: oras records each file's path as its layer title, so
# relative names keep the build host's directory layout out of the published artifact.
( cd "$BUNDLE" && oras push "$REF" \
    --artifact-type "application/vnd.vxedge.part.v1" "${ANNOTATIONS[@]}" \
    "firmware.elf:application/vnd.vxedge.part.firmware" \
    "meta.json:application/vnd.vxedge.part.meta+json" )

echo "== verifying pull round-trip"
PULLDIR="$(mktemp -d)"
trap 'rm -rf "$PULLDIR"' EXIT
oras pull "$REF" -o "$PULLDIR"
for f in firmware.elf meta.json; do
  cmp -s "$BUNDLE/$f" "$PULLDIR/$f" || { echo "error: $f differs after round-trip" >&2; exit 1; }
done
echo "== round-trip OK (firmware.elf, meta.json byte-identical): $REF"
