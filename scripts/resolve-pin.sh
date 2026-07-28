#!/usr/bin/env bash
# Resolve a part's upstream tag to an immutable digest and write it into its part.yaml.
#
# Usage:  ./resolve-pin.sh <part-dir> [--write]
#
# Queries the registry's manifest endpoint directly, so it transfers no image data — the
# alternative (`podman pull` then inspect) would move tens of gigabytes for CARLA and
# Autoware just to read a hash, and would leave those images on the host afterwards.
#
# Without --write it only reports, so you can see what a pin would change before it changes.
set -euo pipefail

PART="${1:?usage: $0 <part-dir> [--write]}"
PART="${PART%/}"
WRITE="${2:-}"

read -r REF <<<"$(python3 -c "
import pathlib, yaml
decl = yaml.safe_load(pathlib.Path('$PART/part.yaml').read_text()) or {}
print((decl.get('upstream') or {}).get('ref', ''))
")"
[[ -n "$REF" ]] || { echo "== $PART declares no upstream.ref — nothing to pin"; exit 0; }

# <registry>/<repo>:<tag>, defaulting the registry the way a container runtime would.
HOST="${REF%%/*}"; REST="${REF#*/}"
if [[ "$HOST" != *.* && "$HOST" != *:* ]]; then HOST="docker.io"; REST="$REF"; fi
TAG="${REST##*:}"; REPO="${REST%:*}"
# Each auth endpoint is written with its own trailing separator, so appending `scope=` is
# correct whether or not the URL already carries a query string.
case "$HOST" in
  docker.io) API="https://registry-1.docker.io"; AUTH="https://auth.docker.io/token?service=registry.docker.io&" ;;
  ghcr.io)   API="https://ghcr.io";              AUTH="https://ghcr.io/token?" ;;
  *)         API="https://$HOST";                AUTH="https://$HOST/token?" ;;
esac

# Registries differ on the field name: Docker Hub returns `token`, GHCR also accepts
# `access_token`. Take whichever is present rather than assuming.
TOKEN="$(curl -sS "${AUTH}scope=repository:${REPO}:pull" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit('')
print(d.get('token') or d.get('access_token') or '')")"
[[ -n "$TOKEN" ]] || { echo "error: could not obtain a pull token for $REPO" >&2; exit 1; }

ACCEPT=(
  -H "Accept: application/vnd.oci.image.index.v1+json"
  -H "Accept: application/vnd.oci.image.manifest.v1+json"
  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json"
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json"
)
DIGEST="$(curl -sSI -H "Authorization: Bearer $TOKEN" "${ACCEPT[@]}" \
  "$API/v2/$REPO/manifests/$TAG" \
  | tr -d '\r' | sed -n 's/^[Dd]ocker-[Cc]ontent-[Dd]igest: //p' | tail -1)"

if [[ ! "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "error: no digest returned for $REF (tag missing, or registry needs auth)" >&2
  exit 1
fi

echo "== $REF"
echo "   $DIGEST"

if [[ "$WRITE" == "--write" ]]; then
  DIGEST="$DIGEST" python3 - "$PART/part.yaml" <<'PY'
import os, pathlib, re, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(); d = os.environ["DIGEST"]
if re.search(r"^\s*digest:\s*sha256:", t, re.M):
    t = re.sub(r"^(\s*)digest:\s*sha256:\S+", rf"\1digest: {d}", t, flags=re.M)
else:
    # Replace the commented placeholder that ships with a scaffolded part, keeping its
    # indentation so the YAML stays valid under the `upstream:` key.
    t = re.sub(r"^(\s*)#\s*digest:.*$", rf"\1digest: {d}", t, count=1, flags=re.M)
p.write_text(t)
PY
  echo "   written to $PART/part.yaml"
fi
