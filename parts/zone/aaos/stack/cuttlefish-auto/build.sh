#!/usr/bin/env bash
# Fetch AOSP's Cuttlefish AAOS 26Q2 build, verify it, and install the vxvhal Vehicle HAL drop-in.
#
#   ./build.sh <out-dir>
#
# Needs `cuttlefish-base` (Google's android-cuttlefish packages) for `cvd`. Downloads about 3 GB
# from ci.android.com and keeps no archives. Every image the fetch writes is checked against
# SHA256SUMS; vbmeta*.img are not pinned because Cuttlefish regenerates them at each launch.
set -euo pipefail

out=${1:?usage: build.sh <out-dir>}
here=$(cd "$(dirname "$0")" && pwd)
build_id=16644040
target=aosp_cf_x86_64_auto-userdebug

mkdir -p "$out"
out=$(cd "$out" && pwd)
cvd fetch --default_build="$build_id/$target" --target_directory="$out" --nokeep_downloaded_archives
(cd "$out" && sha256sum -c "$here/SHA256SUMS")

# Cuttlefish's auto guest dials a host VehicleServer; run vxvhal there instead of AOSP's fake.
if [ ! -e "$out/bin/vhal_proxy_server.aosp" ]; then
    mv "$out/bin/vhal_proxy_server" "$out/bin/vhal_proxy_server.aosp"
fi
install -m 0755 "$here/vhal-proxy-vxvhal.sh" "$out/bin/vhal_proxy_server"
echo "built $out: AAOS 26Q2 ($build_id/$target), vxvhal drop-in installed"
