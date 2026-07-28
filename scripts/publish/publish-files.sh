#!/usr/bin/env bash
# Publish a `config`-layer part: a directory of files (YAML, params, scenario defs) pushed
# as an ORAS artifact. Config parts are not containers — nothing executes — but they still
# need to be versioned, digest-addressed, and classified like every other loadable, because
# a run's parameters are as much an input to a result as the code that consumes them.
#
# Usage:  ./publish-files.sh <part-dir> <tag>
#   e.g.  ./publish-files.sh parts/hpc/sim/config/scenarios 0.1.0
set -euo pipefail

PART="${1:?usage: $0 <part-dir> <tag>}"
TAG="${2:?usage: $0 <part-dir> <tag>}"
PART="${PART%/}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v oras >/dev/null || { echo "error: oras CLI not found — see https://oras.land" >&2; exit 1; }

IFS='/' read -r _parts CLASS SUBTYPE LAYER NAME <<< "${PART#"$ROOT"/}"
[[ "$_parts" == "parts" && -n "${NAME:-}" ]] || {
  echo "error: '$PART' is not a parts/<class>/<subtype>/<layer>/<name> path" >&2; exit 1; }

META="$("$ROOT/scripts/vxpn.py" meta "$PART")"
VXPN="$(python3 -c "import json,sys; print(json.load(sys.stdin)['org.vxedge.pn'])" <<<"$META")"
REF="ghcr.io/vxedge/parts/$CLASS/$SUBTYPE/$LAYER/$NAME:$TAG"

# README documents the part rather than being part of it; part.yaml is this repo's
# declaration about the part, not payload the consumer needs.
mapfile -t FILES < <(cd "$PART" && find . -type f ! -name README.md ! -name part.yaml \
  -printf '%P\n' | LC_ALL=C sort)
[[ ${#FILES[@]} -gt 0 ]] || { echo "error: $PART has no files to publish" >&2; exit 1; }

# Every org.vxedge.* key part.yaml declares becomes a manifest annotation.
mapfile -t ANN_ARGS < <(python3 -c "
import json,sys
for k,v in sorted(json.load(sys.stdin).items()):
    print('--annotation'); print(f'{k}={v}')" <<<"$META")

echo "== $CLASS/$SUBTYPE/$LAYER/$NAME  ($VXPN)  ${#FILES[@]} file(s)"
# Pushed from inside the part dir so the build host's layout stays out of the artifact.
( cd "$PART" && oras push "$REF" \
    --artifact-type "application/vnd.vxedge.part.v1" \
    "${ANN_ARGS[@]}" \
    "${FILES[@]}" )

echo "== verifying pull round-trip"
PULLDIR="$(mktemp -d)"; trap 'rm -rf "$PULLDIR"' EXIT
oras pull "$REF" -o "$PULLDIR"
for f in "${FILES[@]}"; do
  cmp -s "$PART/$f" "$PULLDIR/$f" || { echo "error: $f differs after round-trip" >&2; exit 1; }
done
echo "== published $REF (${#FILES[@]} file(s) byte-identical)"
