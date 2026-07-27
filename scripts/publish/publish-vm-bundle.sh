#!/usr/bin/env bash
# Push a zone-class VM/kernel bundle (vmlinuz + initrd.img + meta.json) to the
# vxparts OCI registry via ORAS, stamping org.vxedge.* annotations read from
# the bundle's own meta.json so classification travels with the artifact.
#
# Usage:  ./publish-vm-bundle.sh <bundle-dir> <ref>
#   e.g.  ./publish-vm-bundle.sh parts/zone/linux/stack/probe-bundle/bundle \
#           ghcr.io/vxedge/parts/zone/linux/stack/probe-bundle:0.1.0
#
# Requires: oras CLI (https://oras.land) — not yet confirmed installed on
# every build host; `oras version` will fail loudly if missing.
set -euo pipefail

BUNDLE="${1:?usage: $0 <bundle-dir> <ref>}"
REF="${2:?usage: $0 <bundle-dir> <ref>}"

command -v oras >/dev/null || { echo "error: oras CLI not found — see https://oras.land/docs/installation" >&2; exit 1; }
META="$BUNDLE/meta.json"
[[ -f "$META" ]] || { echo "error: $META not found — run this bundle's build.sh first" >&2; exit 1; }

# Every org.vxedge.* key the bundle's meta.json declares becomes a manifest annotation, so
# classification travels with the artifact and the registry stays the catalogue (there is
# deliberately no catalog file in this repo — see ../../AGENTS.md).
mapfile -t VX_ANNOTATIONS < <(python3 -c "
import json
meta = json.load(open('$META'))
for k, v in sorted(meta.items()):
    if k.startswith('org.vxedge.'):
        print(f'{k}={v}')
")
[[ ${#VX_ANNOTATIONS[@]} -gt 0 ]] || {
  echo "error: $META declares no org.vxedge.* classification keys" >&2; exit 1; }

ANNOTATIONS=()
for a in "${VX_ANNOTATIONS[@]}"; do ANNOTATIONS+=("--annotation" "$a"); done
echo "== classification: ${VX_ANNOTATIONS[*]}"

echo "== pushing $BUNDLE -> $REF"
# Pushed from inside the bundle dir: oras records each file's path as its layer title, so
# relative names keep the build host's directory layout out of the published artifact.
( cd "$BUNDLE" && oras push "$REF" \
    --artifact-type "application/vnd.vxedge.part.v1" "${ANNOTATIONS[@]}" \
    "vmlinuz:application/vnd.vxedge.part.kernel" \
    "initrd.img:application/vnd.vxedge.part.initrd" \
    "meta.json:application/vnd.vxedge.part.meta+json" )

echo "== verifying pull round-trip"
PULLDIR="$(mktemp -d)"
trap 'rm -rf "$PULLDIR"' EXIT
oras pull "$REF" -o "$PULLDIR"
for f in vmlinuz initrd.img meta.json; do
  cmp -s "$BUNDLE/$f" "$PULLDIR/$f" || { echo "error: $f differs after round-trip" >&2; exit 1; }
done
echo "== round-trip OK (vmlinuz, initrd.img, meta.json byte-identical): $REF"
