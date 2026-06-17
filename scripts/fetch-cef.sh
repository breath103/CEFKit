#!/usr/bin/env bash
# Re-fetch the CEF binary distribution into vendor/cef/. Pinned to the version
# Sources/CEFWrapper was vendored from — bumping this requires re-vendoring
# Sources/CEFWrapper/include + Sources/CEFWrapper/libcef_dll too.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CEF_VERSION="144.0.28+ga64d412+chromium-144.0.7559.255"
PLATFORM="macosarm64"
URL="https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION//+/%2B}_${PLATFORM}.tar.bz2"

mkdir -p "$ROOT/vendor"
cd "$ROOT/vendor"

if [[ -d cef && -d "cef/Release/Chromium Embedded Framework.framework" ]]; then
  echo "vendor/cef already present — delete it first to re-fetch"
  exit 0
fi

echo "==> downloading CEF $CEF_VERSION ($PLATFORM)"
curl -L -o cef.tar.bz2 "$URL"

echo "==> extracting"
tar -xjf cef.tar.bz2
rm cef.tar.bz2
mv "cef_binary_${CEF_VERSION}_${PLATFORM}" cef

echo "==> building libcef_dll_wrapper + cefsimple harness (used by build-demo.sh)"
mkdir -p cef/build
cd cef/build
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DPROJECT_ARCH=arm64 .. >/dev/null
ninja libcef_dll_wrapper cefsimple

echo "==> done. vendor/cef/ ready."
