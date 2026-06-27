#!/usr/bin/env bash
# Build Examples/Demo/Demo.app — pure Swift consumer of the ChromiumKit package.
# Delegates the CEF embedding step to scripts/embed-chromiumkit.sh (the same script
# downstream consumers wire into their Xcode Run Script Build Phase).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="$ROOT/Examples/Demo"
CEF="$ROOT/vendor/cef"
BUILD="$DEMO/build"
APP="$BUILD/Demo.app"
ARCH=arm64

echo "==> swift build (release)"
( cd "$ROOT" && swift build -c release ) >/dev/null

SPM_REL="$ROOT/.build/$ARCH-apple-macosx/release"
CEFWRAPPER_LIB="$BUILD/libChromiumWrapper.a"
CEFOBJC_LIB="$BUILD/libChromiumViewObjC.a"
CEFKIT_LIB="$BUILD/libChromiumKit.a"
mkdir -p "$BUILD"

echo "==> archiving SwiftPM build outputs"
rm -f "$CEFWRAPPER_LIB" "$CEFOBJC_LIB" "$CEFKIT_LIB"
find "$SPM_REL/ChromiumWrapper.build"   -name '*.o' -print0 | xargs -0 ar rcs "$CEFWRAPPER_LIB"
find "$SPM_REL/ChromiumViewObjC.build"  -name '*.o' -print0 | xargs -0 ar rcs "$CEFOBJC_LIB"
find "$SPM_REL/ChromiumKit.build"       -name '*.o' -print0 | xargs -0 ar rcs "$CEFKIT_LIB"

SWIFTC_COMMON=(
  -target "${ARCH}-apple-macosx12.0"
  -I "$SPM_REL/Modules"
  -Xcc -fmodule-map-file="$SPM_REL/ChromiumViewObjC.build/module.modulemap"
  -Xcc -fmodule-map-file="$SPM_REL/ChromiumWrapper.build/module.modulemap"
  -L "$BUILD"
  -lChromiumKit -lChromiumViewObjC -lChromiumWrapper
  -framework Cocoa -framework AppKit
  -Xlinker -search_paths_first
  -Xlinker -ObjC
)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> compiling Swift host"
swiftc "${SWIFTC_COMMON[@]}" "$DEMO/src/demo_main.swift" -o "$APP/Contents/MacOS/Demo"

echo "==> compiling helper"
HELPER_BIN="$BUILD/helper_main"
clang++ -std=c++17 -fno-rtti -fno-exceptions -mmacosx-version-min=12.0 -arch arm64 \
  -I"$ROOT/Sources/ChromiumWrapper" -DUSING_CEF_SHARED \
  "$DEMO/src/helper_main.mm" \
  -Wl,-search_paths_first "$CEFWRAPPER_LIB" \
  -framework Cocoa -framework AppKit -o "$HELPER_BIN"

cp "$DEMO/resources/host.plist" "$APP/Contents/Info.plist"

echo "==> embedding via embed-chromiumkit.sh"
BUILT_PRODUCTS_DIR="$BUILD" \
PRODUCT_NAME="Demo" \
PRODUCT_BUNDLE_IDENTIFIER="work.mirror.cefview.demo" \
CHROMIUMKIT_FRAMEWORK_PATH="$CEF/Release/Chromium Embedded Framework.framework" \
CHROMIUMKIT_HELPER_PATH="$HELPER_BIN" \
CHROMIUMKIT_HELPER_PLIST="$ROOT/scripts/helper.plist.in" \
  "$ROOT/scripts/embed-chromiumkit.sh"

echo "Demo.app built: $APP"
du -sh "$APP"
