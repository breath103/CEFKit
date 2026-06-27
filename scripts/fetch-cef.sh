#!/usr/bin/env bash
# Re-fetch the CEF binary distribution into vendor/cef/. Pinned to the version
# Sources/ChromiumWrapper was vendored from — bumping this requires re-vendoring
# Sources/ChromiumWrapper/include + Sources/ChromiumWrapper/libcef_dll too.

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

echo "==> injecting framework Info.plist (CEF ships without one; Xcode validation needs it)"
FW="$ROOT/vendor/cef/Release/Chromium Embedded Framework.framework"
mkdir -p "$FW/Resources"
cat > "$FW/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>Chromium Embedded Framework</string>
  <key>CFBundleIdentifier</key><string>org.cef.framework</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Chromium Embedded Framework</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>${CEF_VERSION%%+*}</string>
  <key>CFBundleVersion</key><string>${CEF_VERSION%%+*}</string>
  <key>NSPrincipalClass</key><string></string>
</dict>
</plist>
PLIST

echo "==> building libcef_dll_wrapper + cefsimple harness (used by build-demo.sh)"
mkdir -p cef/build
cd cef/build
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DPROJECT_ARCH=arm64 .. >/dev/null
ninja libcef_dll_wrapper cefsimple

echo "==> done. vendor/cef/ ready."
