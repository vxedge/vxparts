#!/usr/bin/env bash
# Pull a published part by digest and give it this part's current classification, keeping its
# payload byte-for-byte. For a change that is only metadata (a new org.vxedge.* key in part.yaml),
# so the payload is not rebuilt.
#
# Usage:  ./restamp-meta.sh <ref@sha256:...> <part-dir> <out-dir>
#   then  ./publish/<kind script>.sh <out-dir> <ref>:<new version>
#
# The pulled meta.json keeps every field it had, except the org.vxedge.* keys, which come from
# `vxpn.py meta` for <part-dir>. The script refuses if any file named in meta.json's `files` does
# not match its recorded sha256, so the payload is proven unchanged.
set -euo pipefail

REF="${1:?usage: $0 <ref@sha256:...> <part-dir> <out-dir>}"
PART="${2:?usage: $0 <ref@sha256:...> <part-dir> <out-dir>}"
OUT="${3:?usage: $0 <ref@sha256:...> <part-dir> <out-dir>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$REF" == *@sha256:* ]] || { echo "error: pull by digest (<ref>@sha256:...)" >&2; exit 1; }
command -v oras >/dev/null || { echo "error: oras CLI not found" >&2; exit 1; }
[[ ! -e "$OUT" ]] || { echo "error: $OUT exists" >&2; exit 1; }
mkdir -p "$OUT"
(cd "$OUT" && oras pull "$REF" >/dev/null)

VX_META="$("$ROOT/scripts/vxpn.py" meta "$PART")" python3 - "$OUT" <<'EOF'
import hashlib, json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
meta = json.loads((out / "meta.json").read_text())
for name, want in meta.get("files", {}).items():
    got = hashlib.sha256((out / name).read_bytes()).hexdigest()
    if got != want:
        sys.exit(f"error: {name} is {got}, meta.json records {want}")
kept = {k: v for k, v in meta.items() if not k.startswith("org.vxedge.")}
new = {k: v for k, v in kept.items() if k == "bundle"}
new.update(json.loads(os.environ["VX_META"]))
new.update({k: v for k, v in kept.items() if k != "bundle"})
(out / "meta.json").write_text(json.dumps(new, indent=2) + "\n")
changed = sorted(set(new) ^ set(meta) | {k for k in new if k in meta and new[k] != meta[k]})
print(f"restamped {out}: payload unchanged ({', '.join(meta.get('files', {}))}); keys changed: {changed}")
EOF
