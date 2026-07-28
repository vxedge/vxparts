#!/usr/bin/env bash
# Publish an hpc/gw-class container part: build its Containerfile, stamp the org.vxedge.*
# classification as OCI labels, push, and verify the labels survived.
#
# Usage:  ./publish-container.sh <part-dir> <tag>
#   e.g.  ./publish-container.sh parts/hpc/ad/app/autoware 0.1.0
#
# Nothing about the part is hardcoded here. Identity comes from the part's path, metadata
# from its part.yaml, and both are resolved by `vxpn.py meta` — this script only knows how
# to drive podman. Set VXPARTS_NO_PUSH=1 to build and verify without publishing (CI).
set -euo pipefail

PART="${1:?usage: $0 <part-dir> <tag>}"
TAG="${2:?usage: $0 <part-dir> <tag>}"
PART="${PART%/}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v podman >/dev/null || { echo "error: podman not found" >&2; exit 1; }
[[ -f "$PART/Containerfile" ]] || { echo "error: $PART/Containerfile not found" >&2; exit 1; }

META="$("$ROOT/scripts/vxpn.py" meta "$PART")"
eval "$(python3 - "$PART" <<'PY'
import json, pathlib, subprocess, sys, shlex, yaml
part = pathlib.Path(sys.argv[1])
decl = yaml.safe_load((part / "part.yaml").read_text()) or {}
up = decl.get("upstream") or {}
print(f"UPSTREAM_REF={shlex.quote(str(up.get('ref','')))}")
print(f"UPSTREAM_DIGEST={shlex.quote(str(up.get('digest','')))}")
PY
)"

# Digest-only rule (ARCHITECTURE §13): a part built on a moving upstream tag is not
# reproducible, so refuse rather than record a digest that lies about what it pins.
# Resolve with:  podman pull <ref> && podman image inspect --format '{{.Digest}}' <ref>
if [[ -n "$UPSTREAM_REF" ]]; then
  if [[ ! "$UPSTREAM_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "error: $PART/part.yaml pins no upstream.digest — see its README" >&2
    exit 1
  fi
  # Repo ref with its tag stripped, plus the digest: a digest ref is exact, and carrying the
  # tag alongside it would let the two disagree. Strips only a trailing tag, so a
  # registry:port prefix survives.
  BUILD_ARGS=(--build-arg "UPSTREAM=$(sed 's/:[^:/]*$//' <<<"$UPSTREAM_REF")@${UPSTREAM_DIGEST}")
else
  BUILD_ARGS=()
fi

read -r CLASS SUBTYPE LAYER NAME VXPN <<<"$(python3 -c "
import json,sys
m = json.load(sys.stdin)
print(m['org.vxedge.class'], m['org.vxedge.subtype'], m['org.vxedge.layer'],
      '$(basename "$PART")', m['org.vxedge.pn'])" <<<"$META")"
REF="ghcr.io/vxedge/parts/$CLASS/$SUBTYPE/$LAYER/$NAME:$TAG"

# Every org.vxedge.* key part.yaml declares becomes an OCI label, so classification and
# licence travel with the artifact rather than living only in this repo.
mapfile -t LABEL_ARGS < <(python3 -c "
import json,sys
for k,v in sorted(json.load(sys.stdin).items()):
    print('--label'); print(f'{k}={v}')" <<<"$META")

echo "== $CLASS/$SUBTYPE/$LAYER/$NAME  ($VXPN)"
python3 -c "
import json,sys
for k,v in sorted(json.load(sys.stdin).items()): print(f'   {k}={v}')" <<<"$META"

podman build -t "$REF" "${LABEL_ARGS[@]}" "${BUILD_ARGS[@]}" "$PART"

if [[ "${VXPARTS_NO_PUSH:-0}" == "1" ]]; then
  echo "== VXPARTS_NO_PUSH=1 — built and labelled, not pushed"
else
  echo "== pushing $REF"
  DIGESTFILE="$(mktemp)"; trap 'rm -f "$DIGESTFILE"' EXIT
  podman push --digestfile "$DIGESTFILE" "$REF"
  PUSHED_DIGEST="$(cat "$DIGESTFILE")"
  # Reported because this is the value a dependent part's part.yaml or an experiment
  # manifest pins. Reading it back off the registry would need a pull token, which for a
  # private package is a needless extra step when the push already knows the answer.
  echo "== digest: $PUSHED_DIGEST"
fi

echo "== verifying labels survived"
# $META goes through the environment, not string interpolation: annotation values are
# free text (licence notes contain quotes and dashes) and must not be able to break out
# into the script.
podman image inspect "$REF" --format '{{json .Labels}}' | VX_META="$META" python3 -c "
import json, os, sys
labels = json.load(sys.stdin) or {}
want = json.loads(os.environ['VX_META'])
wrong = [k for k in want if labels.get(k) != want[k]]
if wrong:
    sys.exit(f'error: labels lost or altered in build: {wrong}')
print(f'   {len(want)} org.vxedge.* label(s) intact')
"

if [[ "${VXPARTS_NO_PUSH:-0}" == "1" ]]; then
  echo "== built and labelled (not published): $REF"
else
  echo "== published $REF"
fi
