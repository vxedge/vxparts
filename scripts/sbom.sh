#!/usr/bin/env bash
# Generate a CycloneDX SBOM for a part, if SBOM tooling is available.
#
# Usage:  ./sbom.sh <part-dir> [target]
#   target defaults to the part directory itself; pass an image ref for container parts.
#
# Deliberately non-blocking: no SBOM tool installed means no SBOM, a clear message, and
# exit 0. SBOM generation must never become the reason a part cannot be published — the
# repo stays *ready* for SBOMs without depending on them. `vxpn.py meta` only emits
# org.vxedge.sbom when the file actually exists, so a missing SBOM is never a false claim.
#
# Once an SBOM exists it feeds two things already on the board: the workspace licensing
# review (docs/ROADMAP.md, go-public prerequisites) and the RxSWIN roll-up computed over a
# vehicle's set of parts (PART-NUMBERING.md open items).
set -euo pipefail

PART="${1:?usage: $0 <part-dir> [target]}"
PART="${PART%/}"
TARGET="${2:-dir:$PART}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT_REL="$(python3 -c "
import sys, yaml, pathlib
decl = yaml.safe_load(pathlib.Path('$PART/part.yaml').read_text()) or {}
print((decl.get('sbom') or {}).get('path', ''))
")"
if [[ -z "$OUT_REL" ]]; then
  echo "== $PART declares no sbom.path in part.yaml — skipping"
  exit 0
fi
OUT="$PART/$OUT_REL"

if command -v syft >/dev/null; then
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
