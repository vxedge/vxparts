#!/usr/bin/env bash
# Fetch the official community SONiC-VS image via `oras pull` and stage it for publishing
# under vxedge's own registry namespace. Not a build: sonic-net/sonic-buildimage's own CI
# produces this artifact; recompiling it here would duplicate a multi-hour upstream pipeline
# for no benefit. "Pull one from an official registry, push it back using oras" — the same
# re-labeling pattern QNX/AAOS use for other third-party-licensed guest images.
#
# Usage:  UPSTREAM_REF=<registry/repo:tag-or-digest> ./build.sh [out-dir]     (default ./bundle)
# Needs:  oras CLI (https://oras.land)
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"

UPSTREAM_REF="${UPSTREAM_REF:?set UPSTREAM_REF=<registry/repo:tag-or-digest>, the official SONiC-VS source (see this parts README -- not yet confirmed, do not guess one)}"

command -v oras >/dev/null || { echo "error: oras CLI not found -- see https://oras.land/docs/installation" >&2; exit 1; }

mkdir -p "$OUT"
echo "== pulling $UPSTREAM_REF"
( cd "$OUT" && oras pull "$UPSTREAM_REF" )

# Upstream's own artifact filename varies by publisher/pipeline, so it's discovered rather
# than assumed -- the one thing asserted is that exactly one disk image lands per pull.
mapfile -t DISKS < <(find "$OUT" -maxdepth 1 -type f \( -iname '*.img*' -o -iname '*.qcow2*' -o -iname '*.vhd*' -o -iname '*.raw*' \))
case "${#DISKS[@]}" in
  0) echo "error: no disk image (*.img*/*.qcow2*/*.vhd*/*.raw*) found in $OUT after pull -- check UPSTREAM_REF" >&2; exit 1 ;;
  1) ;;
  *) echo "error: multiple disk images found in $OUT after pull -- this recipe expects exactly one: ${DISKS[*]}" >&2; exit 1 ;;
esac
DISK="${DISKS[0]}"

# Classification comes from `vxpn.py meta`: identity from this part's own path, declared
# metadata from its part.yaml -- nothing about the part is restated in this recipe.
VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"

VX_META="$VX_META" python3 - "$OUT" "$DISK" "$UPSTREAM_REF" <<'EOF'
import hashlib, json, os, pathlib, sys
out, disk, upstream_ref = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = {"bundle": "sonic-vs"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "upstream_ref": upstream_ref,
    "payload": "SONiC-VS production-NOS twin (config-portability proof only -- ARCHITECTURE.md Sec 7)",
    "files": {disk.name: sha(disk)},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF

echo "== staged: $OUT ($(basename "$DISK"), meta.json)"
echo "== next: ../../../../../scripts/publish/publish-vm-disk.sh $OUT ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:<semver>"
