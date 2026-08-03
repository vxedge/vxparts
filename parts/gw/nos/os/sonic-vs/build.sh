#!/usr/bin/env bash
# Fetch the official community SONiC-VS image from upstream sonic-buildimage's own Azure
# Pipelines artifact storage and stage it for publishing under vxedge's own registry namespace.
# Not a build: sonic-net/sonic-buildimage's own CI produces this artifact (a multi-hour build);
# recompiling it here would duplicate that pipeline for no benefit.
#
# There is no OCI/ORAS-pullable upstream for this artifact (confirmed 2026-08-03: SONiC-VS
# images are Azure Pipelines build outputs, not published to any container/OCI registry, and
# https://sonic.software is an unofficial community index of the same Azure artifacts, not a
# separate stable source) -- so the "pull one from an official registry" half of this part's own
# convention is an HTTPS fetch from Azure's public, unauthenticated build API, not `oras pull`.
# The "push it back using oras" half (publish-vm-disk.sh) is unaffected.
#
# Reproducibility (ARCHITECTURE.md Sec 13): pins one specific Azure build id, not "whatever is
# latest on a branch" -- re-running this script always fetches the exact same bytes (as long as
# Azure retains that build's artifacts), the same guarantee `upstream.digest` gives a registry
# ref. To move the pin to a newer build, query the same public API build.sh itself uses (see
# AZURE_BUILD_ID resolution below) for a fresh build id and update it here deliberately -- there
# is no separate "find latest" helper in this directory, so a version bump is always a reviewed
# one-line change, not a script run unattended.
#
# Usage:  ./build.sh [out-dir]     (default ./bundle)
#         AZURE_BUILD_ID=<id> ./build.sh [out-dir]   to override the pin
set -euo pipefail

PART_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$PART_DIR/bundle}"
VXPARTS_ROOT="$(cd "$PART_DIR/../../../../.." && pwd)"

# Pinned 2026-08-03: Azure.sonic-buildimage.official.vs (definition 142), branch 202505,
# buildNumber 20260803.4, sourceVersion ff3c0c9f686a1d0dbddbe813b233b3b7a51bd8e2 -- verified via
# https://dev.azure.com/mssonic/build/_apis/build/builds/1182664?api-version=6.0 (public, no
# auth). Build page: https://dev.azure.com/mssonic/build/_build/results?buildId=1182664
AZURE_BUILD_ID="${AZURE_BUILD_ID:-1182664}"

echo "== resolving artifact download URL for Azure build $AZURE_BUILD_ID"
ARTF_JSON="$(curl -sS "https://dev.azure.com/mssonic/build/_apis/build/builds/${AZURE_BUILD_ID}/artifacts?artifactName=sonic-buildimage.vs&api-version=5.1")"
BASE_URL="$(echo "$ARTF_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["resource"]["downloadUrl"])')"
[[ -n "$BASE_URL" && "$BASE_URL" != "None" ]] || {
  echo "error: could not resolve a download URL for build $AZURE_BUILD_ID -- has it expired? see https://dev.azure.com/mssonic/build/_build/results?buildId=${AZURE_BUILD_ID}" >&2
  exit 1
}
# The artifact API's own downloadUrl points at the whole build output (tens of GB, format=zip);
# `subpath` narrows it to the one file this part actually needs, the same transform
# https://sonic.software's own generator script uses against this same public API. `sed`, not
# bash's `${var/pattern/replacement}`: confirmed live that form silently mangles a replacement
# containing its own `/` characters (it treats the second `/` as ending the replacement clause
# rather than as a literal character), so it must not be used here.
DISK_URL="$(echo "$BASE_URL" | sed 's/format=zip/format=file\&subpath=\/target\/sonic-vs.img.gz/')"

mkdir -p "$OUT"
echo "== downloading sonic-vs.img.gz (~1.9GB compressed)"
curl -sS -o "$OUT/sonic-vs.img.gz" "$DISK_URL"

echo "== decompressing"
gunzip -kf "$OUT/sonic-vs.img.gz"
DISK="$OUT/sonic-vs.img"

# Classification comes from `vxpn.py meta`: identity from this part's own path, declared
# metadata from its part.yaml -- nothing about the part is restated in this recipe.
VX_META="$("$VXPARTS_ROOT/scripts/vxpn.py" meta "$PART_DIR")"

VX_META="$VX_META" python3 - "$OUT" "$DISK" "$AZURE_BUILD_ID" <<'EOF'
import hashlib, json, os, pathlib, sys
out, disk, build_id = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = {"bundle": "sonic-vs"}
meta.update(json.loads(os.environ["VX_META"]))
meta.update({
    "upstream_azure_build_id": build_id,
    "upstream_azure_build_url": f"https://dev.azure.com/mssonic/build/_build/results?buildId={build_id}",
    "payload": "SONiC-VS production-NOS twin (config-portability proof only -- ARCHITECTURE.md Sec 7)",
    "files": {disk.name: sha(disk)},
})
(out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta, indent=2))
EOF

echo "== staged: $OUT ($(basename "$DISK"), meta.json)"
echo "== next: ../../../../../scripts/publish/publish-vm-disk.sh $OUT ghcr.io/vxedge/parts/gw/nos/os/sonic-vs:<semver>"
echo "== IMPORTANT: do not boot $DISK before publishing. QEMU opens a qcow2 read-write by"
echo "   default, and SONiC's own first-boot sequence writes to the disk (first-boot marker"
echo "   removal, log files, ...) -- found live 2026-08-03: a boot smoke-test changed the"
echo "   image's own sha256 out from under this meta.json. Boot a *copy* to verify a build,"
echo "   never this staged one, or re-run build.sh again afterward before publishing."
