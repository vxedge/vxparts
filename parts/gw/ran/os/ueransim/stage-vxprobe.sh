#!/usr/bin/env bash
# Stages vxprobe (vxagents, a separate git repo not nested under this one) into this part's
# build context. Containerfiles are sandboxed to their own directory, so publish-container.sh's
# `podman build ... "$PART"` can't reach a sibling repo directly — this must run first.
# Ported from vxedge/containers/fiveg/build-vx5g-ran.sh (same staging step, new location).
#
# Deliberately not named build.sh: vxpn.py lint treats Containerfile/build.sh as mutually
# exclusive build recipes (exactly one may decide how a part is built) — this is a prebuild
# helper for the Containerfile recipe, not a competing recipe of its own.
#
# Usage:  ./stage-vxprobe.sh                      # stage only
#         ./stage-vxprobe.sh && ../../../../../scripts/publish/publish-container.sh \
#             parts/gw/ran/os/ueransim <tag>       # stage, then publish (or VXPARTS_NO_PUSH=1)
set -euo pipefail
cd "$(dirname "$0")"

VXAGENTS_DIR="../../../../../../vxagents"
if [ ! -d "$VXAGENTS_DIR" ]; then
  echo "error: expected sibling repo at $VXAGENTS_DIR (vxedge/vxagents), not found" >&2
  exit 1
fi

cargo build --release -p vxprobe --manifest-path "$VXAGENTS_DIR/Cargo.toml"
mkdir -p ./bin
cp "$VXAGENTS_DIR/target/release/vxprobe" ./bin/vxprobe.bin

echo "== staged bin/vxprobe.bin — now run publish-container.sh (or podman build) against this part dir"
echo "== bin/ is repo-gitignored (vxparts/.gitignore: parts/**/bin/) — no manual cleanup needed"
