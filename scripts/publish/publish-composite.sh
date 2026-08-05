#!/usr/bin/env bash
# Publish a `stack`-layer composite: an OCI image index over already-published constituent
# parts, so a released stack (or, per Track D, a vehicle) is one pullable, digest-addressed
# unit instead of a table of parts an operator has to pull individually.
#
# Usage:  ./publish-composite.sh <part-dir> <tag>
#   e.g.  ./publish-composite.sh parts/hpc/ad/stack/ad-baseline 0.1.0
#
# The part's own part.yaml declares its constituents:
#
#   constituents:
#     - hpc/ad/middleware/ros2-humble:0.1.0
#     - hpc/ad/middleware/carla-client:0.1.0
#     - hpc/ad/app/autoware:0.1.0
#     - hpc/ad/config/autoware-params:0.1.0
#
# each already published at that tag by its own publish-*.sh script — this one does not build
# anything, it only indexes.
#
# The wrinkle `oras manifest index create` states in its own --help ("all manifests should be
# in the same repository") is not incidental: an OCI index can only reference manifests that
# already exist as blobs in ITS OWN repository — a registry does not let one repo's index
# reference another repo's manifest by digest. Since every constituent here lives at a
# different class/subtype/layer/name path (a different repository under
# ghcr.io/vxedge/parts/...) by design, each constituent's manifest is first cross-mounted
# into the composite's own repo with `oras cp` (same registry, so this is a manifest/blob
# mount, not a re-upload), and only then does `oras manifest index create` reference the
# resulting in-repo digests. Skipping the `cp` step produces an index create failure against
# a real registry, not a local one — a local single-repo test would not catch it.
set -euo pipefail

PART="${1:?usage: $0 <part-dir> <tag>}"
TAG="${2:?usage: $0 <part-dir> <tag>}"
PART="${PART%/}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="${VXPARTS_REGISTRY:-ghcr.io/vxedge/parts}"

command -v oras >/dev/null || { echo "error: oras CLI not found — see https://oras.land" >&2; exit 1; }

IFS='/' read -r _parts CLASS SUBTYPE LAYER NAME <<< "${PART#"$ROOT"/}"
[[ "$_parts" == "parts" && -n "${NAME:-}" ]] || {
  echo "error: '$PART' is not a parts/<class>/<subtype>/<layer>/<name> path" >&2; exit 1; }
[[ "$LAYER" == "stack" ]] || {
  echo "error: '$PART' is layer '$LAYER' — composites are stack-layer parts only" >&2; exit 1; }

BUILD="$("$ROOT/scripts/vxpn.py" build "$PART")"
[[ "$BUILD" == "composite" ]] || {
  echo "error: $PART/part.yaml declares build: $BUILD — publish-composite.sh only handles" \
       "build: composite (default for the stack layer; a part overrides it explicitly if" \
       "it's genuinely built as one artifact, e.g. probe-bundle)" >&2; exit 1; }

META="$("$ROOT/scripts/vxpn.py" meta "$PART")"
VXPN="$(python3 -c "import json,sys; print(json.load(sys.stdin)['org.vxedge.pn'])" <<<"$META")"
REF="$REGISTRY/$CLASS/$SUBTYPE/$LAYER/$NAME:$TAG"

mapfile -t CONSTITUENTS < <(python3 -c "
import pathlib, sys, yaml
decl = yaml.safe_load((pathlib.Path('$PART') / 'part.yaml').read_text()) or {}
c = decl.get('constituents') or []
if not c:
    sys.exit('error: $PART/part.yaml declares no constituents: list')
for entry in c:
    print(entry)
" 2>&1)
if [[ ${#CONSTITUENTS[@]} -eq 1 && "${CONSTITUENTS[0]}" == error:* ]]; then
  echo "${CONSTITUENTS[0]}" >&2; exit 1
fi

echo "== $CLASS/$SUBTYPE/$LAYER/$NAME  ($VXPN)  ${#CONSTITUENTS[@]} constituent(s)"

# Cross-mount each constituent's manifest into this composite's own repo (see header comment
# for why this step exists) and record the digest it lands at there.
DIGESTS=()
for entry in "${CONSTITUENTS[@]}"; do
  CPATH="${entry%:*}"; CTAG="${entry##*:}"
  [[ "$CPATH" != "$entry" ]] || { echo "error: constituent '$entry' has no :<tag>" >&2; exit 1; }
  CDIR="$ROOT/parts/$CPATH"
  [[ -d "$CDIR" ]] || { echo "error: constituent part dir not found: $CDIR" >&2; exit 1; }
  CVXPN="$("$ROOT/scripts/vxpn.py" meta "$CDIR" | python3 -c "import json,sys; print(json.load(sys.stdin)['org.vxedge.pn'])")"
  CSRC="$REGISTRY/$CPATH:$CTAG"
  echo "== mounting $CSRC ($CVXPN) into $REGISTRY/$CLASS/$SUBTYPE/$LAYER/$NAME"
  # A copy is content-addressed: the manifest lands at the SAME digest in the destination
  # repo as it had in the source repo, so resolving the source tells us the digest to
  # reference in the index without needing to parse `oras cp`'s own output.
  oras cp "$CSRC" "$REGISTRY/$CLASS/$SUBTYPE/$LAYER/$NAME"
  DIGEST="$(oras resolve "$CSRC")"
  DIGESTS+=("$DIGEST")
done

mapfile -t ANN_ARGS < <(python3 -c "
import json,sys
for k,v in sorted(json.load(sys.stdin).items()):
    print('--annotation'); print(f'{k}={v}')" <<<"$META")

echo "== creating index $REF over ${#DIGESTS[@]} constituent(s)"
oras manifest index create "$REF" \
  --artifact-type "application/vnd.vxedge.part.v1" \
  "${ANN_ARGS[@]}" \
  "${DIGESTS[@]}"

echo "== verifying index contents"
oras manifest fetch "$REF" | python3 -c "
import json, sys
idx = json.load(sys.stdin)
got = sorted(m['digest'] for m in idx.get('manifests', []))
want = sorted('$(IFS=,; echo "${DIGESTS[*]}")'.split(','))
if got != want:
    sys.exit(f'error: index at $REF references {got}, expected {want}')
print(f'   {len(got)} manifest(s) in index, digests match')
"

echo "== published $REF ($VXPN, composite over ${#CONSTITUENTS[@]} constituent(s))"
