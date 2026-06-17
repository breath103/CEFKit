#!/usr/bin/env bash
# Build HelloCEF.app — example consumer of CEFKit.
#
# This is the same pattern a third-party consumer would use:
#   1. swift build the app + helper executables
#   2. Assemble HelloCEF.app/Contents/{MacOS,Frameworks,Resources}
#   3. Run scripts/embed-cefkit.sh (from the CEFKit package) to copy the
#      framework + assemble the 5 helper bundles + sign
#
# In Xcode this whole thing is replaced by a single Run Script Build Phase
# that invokes embed-cefkit.sh. We do it as shell here so the example has no
# Xcode-project file to maintain.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/../.." && pwd)"     # CEFKit package root
BUILD="$HERE/build"
APP="$BUILD/HelloCEF.app"

echo "==> swift build (release)"
( cd "$HERE" && swift build -c release ) >/dev/null

EXE_DIR="$HERE/.build/arm64-apple-macosx/release"
APP_BIN="$EXE_DIR/HelloCEF"
HELPER_BIN="$EXE_DIR/HelloCEFHelper"
[[ -x "$APP_BIN"    ]] || { echo "error: HelloCEF binary missing at $APP_BIN" >&2; exit 1; }
[[ -x "$HELPER_BIN" ]] || { echo "error: HelloCEFHelper binary missing at $HELPER_BIN" >&2; exit 1; }

echo "==> assembling HelloCEF.app shell"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$APP_BIN" "$APP/Contents/MacOS/HelloCEF"
cp "$HERE/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> embedding CEF via $PKG/scripts/embed-cefkit.sh"
BUILT_PRODUCTS_DIR="$BUILD" \
PRODUCT_NAME="HelloCEF" \
PRODUCT_BUNDLE_IDENTIFIER="org.example.HelloCEF" \
CEFKIT_FRAMEWORK_PATH="$PKG/vendor/cef/Release/Chromium Embedded Framework.framework" \
CEFKIT_HELPER_PATH="$HELPER_BIN" \
CEFKIT_HELPER_PLIST="$PKG/scripts/helper.plist.in" \
  "$PKG/scripts/embed-cefkit.sh"

echo
echo "HelloCEF.app built: $APP"
du -sh "$APP"
