#!/usr/bin/env bash
# Stage the vxagents release binary this part packages into bin/, after verifying the tarball.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
version=0.2.0
want=55b4bf3b449cad32b614be35db12431dcdf917ef49c04de2b3762c2a1af01ab9
tarball=vxagents-$version-x86_64-unknown-linux-gnu.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh release download "v$version" --repo vxedge/vxagents -p "$tarball" -D "$work"
echo "$want  $work/$tarball" | sha256sum -c -
tar xzf "$work/$tarball" -C "$work"
mkdir -p "$here/bin"
install -m 0755 "$work/vxagents-$version-x86_64-unknown-linux-gnu/vxtraffic" "$here/bin/vxtraffic"
echo "staged vxtraffic $version"
