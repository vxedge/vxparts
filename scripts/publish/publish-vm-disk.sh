#!/usr/bin/env bash
# Push a single-disk VM appliance part (one complete disk image + meta.json) to the vxparts
# OCI registry via ORAS, stamping org.vxedge.* annotations read from the bundle's own
# meta.json so classification travels with the artifact.
#
# Sibling to publish-vm-bundle.sh (kernel+initrd zone guests): that script's argv is hardcoded
# to the vmlinuz/initrd.img pair, which doesn't fit a part that ships as one complete disk
# image instead (SONiC-VS today, any future full-appliance VM twin later) -- "one utility per
# artifact kind" (scripts/publish/README.md) rather than overloading the kernel+initrd shape
# to also handle a different one.
#
# Usage:  ./publish-vm-disk.sh <bundle-dir> <ref>
#   e.g.  ./publish-vm-disk.sh parts/gw/nos/os/sonic-vs/bundle \
#           ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:4.2.0
#
# Requires: oras CLI (https://oras.land)
set -euo pipefail

BUNDLE="${1:?usage: $0 <bundle-dir> <ref>}"
REF="${2:?usage: $0 <bundle-dir> <ref>}"

command -v oras >/dev/null || { echo "error: oras CLI not found -- see https://oras.land/docs/installation" >&2; exit 1; }
META="$BUNDLE/meta.json"
[[ -f "$META" ]] || { echo "error: $META not found -- run this part's build.sh first" >&2; exit 1; }

# Every org.vxedge.* key the bundle's meta.json declares becomes a manifest annotation, so
# classification travels with the artifact and the registry stays the catalogue (there is
# deliberately no catalog file in this repo -- see ../../AGENTS.md).
mapfile -t VX_ANNOTATIONS < <(python3 -c "
import json
meta = json.load(open('$META'))
for k, v in sorted(meta.items()):
    if k.startswith('org.vxedge.'):
        print(f'{k}={v}')
")
[[ ${#VX_ANNOTATIONS[@]} -gt 0 ]] || {
  echo "error: $META declares no org.vxedge.* classification keys" >&2; exit 1; }

# The one disk file meta.json's own `files` map names -- whatever build.sh actually staged,
# never a hardcoded filename, since upstream artifact names vary by publisher.
DISK="$(python3 -c "
import json
meta = json.load(open('$META'))
files = list(meta.get('files', {}).keys())
assert len(files) == 1, f'expected exactly one disk file in meta.json, found {files}'
print(files[0])
")"

ANNOTATIONS=()
for a in "${VX_ANNOTATIONS[@]}"; do ANNOTATIONS+=("--annotation" "$a"); done
echo "== classification: ${VX_ANNOTATIONS[*]}"
echo "== disk artifact: $DISK"

echo "== pushing $BUNDLE -> $REF"
# Pushed from inside the bundle dir: oras records each file's path as its layer title, so
# relative names keep the build host's directory layout out of the published artifact.
( cd "$BUNDLE" && oras push "$REF" \
    --artifact-type "application/vnd.vxedge.part.v1" "${ANNOTATIONS[@]}" \
    "$DISK:application/vnd.vxedge.part.disk" \
    "meta.json:application/vnd.vxedge.part.meta+json" )

echo "== verifying pull round-trip"
PULLDIR="$(mktemp -d)"
trap 'rm -rf "$PULLDIR"' EXIT
oras pull "$REF" -o "$PULLDIR"
for f in "$DISK" meta.json; do
  cmp -s "$BUNDLE/$f" "$PULLDIR/$f" || { echo "error: $f differs after round-trip" >&2; exit 1; }
done
echo "== round-trip OK ($DISK, meta.json byte-identical): $REF"
