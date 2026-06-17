#!/usr/bin/env bash
# Build CEF artifacts for the CEFView SwiftPM package.
#
# Inputs:  vendor/cef/  (extracted CEF binary distribution)
# Outputs: artifacts/CEF.xcframework
#          artifacts/cef_helper_binary  (built libcef_dll_wrapper + helper exec)
#
# libcef_dll_wrapper sources are NOT prebuilt — they ship in the SwiftPM package
# as a C++ target and compile in-tree on the consumer's machine.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CEF_DIR="$ROOT/vendor/cef"
ART="$ROOT/artifacts"

if [[ ! -d "$CEF_DIR/Release/Chromium Embedded Framework.framework" ]]; then
  echo "error: CEF binary distribution not found at $CEF_DIR" >&2
  echo "       extract cef_binary_*.tar.bz2 into vendor/cef/ first" >&2
  exit 1
fi

mkdir -p "$ART"
rm -rf "$ART/CEF.xcframework"

echo "==> packaging Chromium Embedded Framework as XCFramework"
xcodebuild -create-xcframework \
  -framework "$CEF_DIR/Release/Chromium Embedded Framework.framework" \
  -output "$ART/CEF.xcframework"

echo "==> done"
echo "    $ART/CEF.xcframework  $(du -sh "$ART/CEF.xcframework" | awk '{print $1}')"

# TODO(phase 6): add x86_64 by extracting macosx64 tarball into vendor/cef-x64/
# and re-running -create-xcframework with both -framework flags.
