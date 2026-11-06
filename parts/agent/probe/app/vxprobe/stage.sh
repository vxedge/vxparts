#!/usr/bin/env bash
# Stage the vxagents release binary this part packages into bin/, after verifying the tarball.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
version=0.1.1
want=e178b18d81eb0cd9dede52f7ba5f94f2afef11b56a60f530009f1053e4b4edda
tarball=vxagents-$version-x86_64-unknown-linux-gnu.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh release download "v$version" --repo vxedge/vxagents -p "$tarball" -D "$work"
echo "$want  $work/$tarball" | sha256sum -c -
tar xzf "$work/$tarball" -C "$work"
mkdir -p "$here/bin"
install -m 0755 "$work/vxagents-$version-x86_64-unknown-linux-gnu/vxprobe" "$here/bin/vxprobe"
echo "staged vxprobe $version"
