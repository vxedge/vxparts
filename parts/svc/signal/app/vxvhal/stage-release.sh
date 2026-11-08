#!/usr/bin/env bash
# Stage the vxvhal release binary and its default mapping into bin/, after verifying the tarball.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
version=0.1.1
want=fd5d7076480f4cda4625c787b5960ee560f2a16f27861fd550f227723759a6e3
name=vxvhal-$version-x86_64-unknown-linux-musl
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh release download "v$version" --repo vxedge/vxvhal -p "$name.tar.gz" -D "$work"
echo "$want  $work/$name.tar.gz" | sha256sum -c -
tar xzf "$work/$name.tar.gz" -C "$work"
mkdir -p "$here/bin"
install -m 0755 "$work/$name/vxvhal" "$here/bin/vxvhal"
install -m 0644 "$work/$name/mapping.yaml" "$here/bin/mapping.yaml"
echo "staged vxvhal $version"
