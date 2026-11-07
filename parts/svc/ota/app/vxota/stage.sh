#!/usr/bin/env bash
# Stage the vxota release binary this part packages into bin/, after verifying the tarball.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
version=0.1.1
want=4205fb2c08a0e25daefe2afd3b70f7531a75d1829e1787d7158f1e3c0a868f54
tarball=vxota-$version-x86_64-unknown-linux-gnu.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh release download "v$version" --repo vxedge/vxota -p "$tarball" -D "$work"
echo "$want  $work/$tarball" | sha256sum -c -
tar xzf "$work/$tarball" -C "$work"
mkdir -p "$here/bin"
install -m 0755 "$work/vxota-$version-x86_64-unknown-linux-gnu/vxota" "$here/bin/vxota"
echo "staged vxota $version"
