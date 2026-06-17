#!/usr/bin/env bash
# Build Examples/Demo/Demo.app — pure Swift consumer of the CEFKit package.
# Delegates the CEF embedding step to scripts/embed-cefkit.sh (the same script
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
CEFWRAPPER_LIB="$BUILD/libCEFWrapper.a"
CEFOBJC_LIB="$BUILD/libCEFViewObjC.a"
CEFKIT_LIB="$BUILD/libCEFKit.a"
mkdir -p "$BUILD"

echo "==> archiving SwiftPM build outputs"
rm -f "$CEFWRAPPER_LIB" "$CEFOBJC_LIB" "$CEFKIT_LIB"
find "$SPM_REL/CEFWrapper.build"   -name '*.o' -print0 | xargs -0 ar rcs "$CEFWRAPPER_LIB"
find "$SPM_REL/CEFViewObjC.build"  -name '*.o' -print0 | xargs -0 ar rcs "$CEFOBJC_LIB"
find "$SPM_REL/CEFKit.build"       -name '*.o' -print0 | xargs -0 ar rcs "$CEFKIT_LIB"

SWIFTC_COMMON=(
  -target "${ARCH}-apple-macosx12.0"
  -I "$SPM_REL/Modules"
  -Xcc -fmodule-map-file="$SPM_REL/CEFViewObjC.build/module.modulemap"
  -Xcc -fmodule-map-file="$SPM_REL/CEFWrapper.build/module.modulemap"
  -L "$BUILD"
  -lCEFKit -lCEFViewObjC -lCEFWrapper
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
  -I"$ROOT/Sources/CEFWrapper" -DUSING_CEF_SHARED \
  "$DEMO/src/helper_main.mm" \
  -Wl,-search_paths_first "$CEFWRAPPER_LIB" \
  -framework Cocoa -framework AppKit -o "$HELPER_BIN"

cp "$DEMO/resources/host.plist" "$APP/Contents/Info.plist"

echo "==> embedding via embed-cefkit.sh"
BUILT_PRODUCTS_DIR="$BUILD" \
PRODUCT_NAME="Demo" \
PRODUCT_BUNDLE_IDENTIFIER="work.mirror.cefview.demo" \
CEFKIT_FRAMEWORK_PATH="$CEF/Release/Chromium Embedded Framework.framework" \
CEFKIT_HELPER_PATH="$HELPER_BIN" \
CEFKIT_HELPER_PLIST="$ROOT/scripts/helper.plist.in" \
  "$ROOT/scripts/embed-cefkit.sh"

echo "Demo.app built: $APP"
du -sh "$APP"
