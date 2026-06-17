#!/usr/bin/env bash
# embed-cefview.sh — embed CEF framework + 5 helper apps into a host .app bundle.
#
# Designed to run from an Xcode "Run Script Build Phase" after Xcode has
# produced the host app at $BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app. Picks up
# everything else from environment variables Xcode sets.
#
# Required env:
#   BUILT_PRODUCTS_DIR     — $TARGET_BUILD_DIR from Xcode
#   PRODUCT_NAME           — host app target name (no .app suffix)
#   PRODUCT_BUNDLE_IDENTIFIER — host bundle id (e.g. com.acme.MyApp)
#   CEFVIEW_FRAMEWORK_PATH — path to "Chromium Embedded Framework.framework"
#   CEFVIEW_HELPER_PATH    — path to a prebuilt helper executable (one binary
#                            is reused for all 5 helpers, only plist differs)
#   CEFVIEW_HELPER_PLIST   — path to helper.plist.in template
#
# Optional env:
#   EXPANDED_CODE_SIGN_IDENTITY — Xcode-provided signing identity (default: -)
#
# Standalone usage:
#   BUILT_PRODUCTS_DIR=out PRODUCT_NAME=Demo PRODUCT_BUNDLE_IDENTIFIER=foo.demo \
#   CEFVIEW_FRAMEWORK_PATH=... CEFVIEW_HELPER_PATH=... CEFVIEW_HELPER_PLIST=... \
#   ./scripts/embed-cefview.sh

set -euo pipefail

: "${BUILT_PRODUCTS_DIR:?required}"
: "${PRODUCT_NAME:?required}"
: "${PRODUCT_BUNDLE_IDENTIFIER:?required}"
: "${CEFVIEW_FRAMEWORK_PATH:?required}"
: "${CEFVIEW_HELPER_PATH:?required}"
: "${CEFVIEW_HELPER_PLIST:?required}"

SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:--}"
APP="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"
FRAMEWORKS="$APP/Contents/Frameworks"

[[ -d "$APP" ]] || { echo "error: host app not found at $APP" >&2; exit 1; }
mkdir -p "$FRAMEWORKS"

echo "[CEFView] embedding into $APP"

echo "[CEFView]  → copying Chromium Embedded Framework"
rm -rf "$FRAMEWORKS/Chromium Embedded Framework.framework"
cp -R "$CEFVIEW_FRAMEWORK_PATH" "$FRAMEWORKS/Chromium Embedded Framework.framework"

embed_helper() {
  local label="$1"      # ""  | " (GPU)" | " (Renderer)" | " (Plugin)" | " (Alerts)"
  local id_suffix="$2"  # ""  | ".gpu"   | ".renderer"   | ".plugin"   | ".alerts"
  local exec_name="$PRODUCT_NAME Helper${label}"
  local app="$FRAMEWORKS/${exec_name}.app"
  local bundle_id="${PRODUCT_BUNDLE_IDENTIFIER}.helper${id_suffix}"

  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS"
  cp "$CEFVIEW_HELPER_PATH" "$app/Contents/MacOS/${exec_name}"

  sed -e "s|__EXECUTABLE_NAME__|${exec_name}|g" \
      -e "s|__BUNDLE_ID__|${bundle_id}|g" \
      "$CEFVIEW_HELPER_PLIST" > "$app/Contents/Info.plist"
}

echo "[CEFView]  → assembling 5 helper bundles"
embed_helper ""            ""
embed_helper " (GPU)"      ".gpu"
embed_helper " (Renderer)" ".renderer"
embed_helper " (Plugin)"   ".plugin"
embed_helper " (Alerts)"   ".alerts"

echo "[CEFView]  → signing framework (identity: $SIGN_ID)"
codesign --force --sign "$SIGN_ID" --timestamp=none \
  "$FRAMEWORKS/Chromium Embedded Framework.framework"

# NB: do NOT codesign helper bundles. Their executables are linker-signed at
# build time and Chromium's IPC handshake validates that exact signature.
# Re-codesigning the bundle wraps the binary in a new sig and breaks helpers
# with a CHECK fail in cef_execute_process.

echo "[CEFView]  → signing host"
codesign --force --sign "$SIGN_ID" --timestamp=none "$APP"

echo "[CEFView]  done"
