#!/usr/bin/env bash
# Stage the vxagents release vxprobe this part bundles into bin/, after verifying the tarball.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
version=0.2.3
want=d416481e1e898d5c6fdd327f43b9008a7e839d75d0012ad05ffc426d54853286
tarball=vxagents-$version-x86_64-unknown-linux-gnu.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh release download "v$version" --repo vxedge/vxagents -p "$tarball" -D "$work"
echo "$want  $work/$tarball" | sha256sum -c -
tar xzf "$work/$tarball" -C "$work"
mkdir -p "$here/bin"
install -m 0755 "$work/vxagents-$version-x86_64-unknown-linux-gnu/vxprobe" "$here/bin/vxprobe"
echo "staged vxprobe $version"
