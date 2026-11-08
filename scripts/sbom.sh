#!/usr/bin/env bash
# Generate a CycloneDX SBOM for a part, if SBOM tooling is available.
#
# Usage:  ./sbom.sh <part-dir> [target]
#   target defaults to the part directory itself; pass an image ref for container parts.
#
# A part whose upstream image ships its own SBOM names that file in part.yaml as
# `sbom.from_image`. It is copied out of the image pinned by `upstream.ref` and `upstream.digest`,
# because a scanner sees nothing inside a static binary that its own build could list.
#
# Deliberately non-blocking: no SBOM tool installed means no SBOM, a clear message, and
# exit 0. SBOM generation must never become the reason a part cannot be published — the
# repo stays *ready* for SBOMs without depending on them. `vxpn.py meta` only emits
# org.vxedge.sbom when the file actually exists, so a missing SBOM is never a false claim.
#
# An SBOM is an input to the licensing review of a part's bundled components, and to an
# RxSWIN roll-up over a vehicle's set of parts (PART-NUMBERING.md, not implemented).
set -euo pipefail

PART="${1:?usage: $0 <part-dir> [target]}"
PART="${PART%/}"
TARGET="${2:-dir:$PART}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -r OUT_REL FROM_IMAGE UPSTREAM <<<"$(python3 -c "
import re, yaml, pathlib
decl = yaml.safe_load(pathlib.Path('$PART/part.yaml').read_text()) or {}
sbom = decl.get('sbom') or {}
up = decl.get('upstream') or {}
ref = re.sub(r':[^:/]*$', '', str(up.get('ref', ''))) if up.get('ref') else ''
pinned = f\"{ref}@{up['digest']}\" if ref and up.get('digest') else '-'
print(sbom.get('path', '') or '-', sbom.get('from_image', '') or '-', pinned)
")"
[[ "$OUT_REL" == "-" ]] && OUT_REL=""
if [[ -z "$OUT_REL" ]]; then
  echo "== $PART declares no sbom.path in part.yaml — skipping"
  exit 0
fi
OUT="$PART/$OUT_REL"

if [[ "$FROM_IMAGE" != "-" ]]; then
  [[ "$UPSTREAM" =~ @sha256:[0-9a-f]{64}$ ]] || { echo "error: $PART: sbom.from_image needs a pinned upstream" >&2; exit 1; }
  command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
  CID="$(podman create --platform linux/amd64 "$UPSTREAM")"
  trap 'podman rm "$CID" >/dev/null 2>&1 || true' EXIT
  podman cp "$CID:$FROM_IMAGE" "$OUT"
  python3 -c "
import json, sys
d = json.load(open('$OUT'))
assert d.get('bomFormat') == 'CycloneDX', 'not a CycloneDX SBOM'
print(f\"== SBOM copied from {sys.argv[1]}:{sys.argv[2]}: CycloneDX {d.get('specVersion')}, {len(d.get('components', []))} components\")
" "$UPSTREAM" "$FROM_IMAGE"
elif command -v syft >/dev/null; then
  mkdir -p "$(dirname "$OUT")"
  syft "$TARGET" -o cyclonedx-json="$OUT"
  echo "== SBOM written: $OUT"
elif command -v cyclonedx-py >/dev/null; then
  mkdir -p "$(dirname "$OUT")"
  cyclonedx-py environment -o "$OUT" --output-format json
  echo "== SBOM written: $OUT"
else
  echo "== no SBOM tool found (syft or cyclonedx-py) — skipping, not an error"
  echo "   install syft:  curl -sSfL https://get.anchore.io/syft | sh -s -- -b ~/.local/bin"
  exit 0
fi

"$ROOT/scripts/vxpn.py" meta "$PART" | grep -q "org.vxedge.sbom" \
  && echo "== org.vxedge.sbom will ride to the registry on next publish"
