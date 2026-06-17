# Integrating CEFView into a macOS app

This is the WKWebView-style integration story. You add CEFView as a Swift
Package dependency in Xcode, add one Run Script Build Phase, and ship.

---

## Why a Run Script Phase

Chromium Embedded Framework needs **five sibling helper `.app` bundles** in
your host's `Contents/Frameworks/` directory. SwiftPM has no concept of
embedding nested `.app` bundles, so the package ships:

- `Chromium Embedded Framework.framework` as an XCFramework (binaryTarget) —
  Xcode embeds it for you automatically when you depend on the `CEFView`
  product.
- A prebuilt **helper executable** + plist template — your Run Script copies
  this into five `.app` bundles named `${PRODUCT_NAME} Helper{|.GPU|.Renderer|.Plugin|.Alerts}.app`.

You write **zero** custom embed logic. The package provides
`scripts/embed-cefview.sh`. Your Run Script Phase invokes it.

---

## Adding the dependency in Xcode

1. **File → Add Package Dependencies…**
2. Enter the package URL (or pick "Add Local…" pointing at your checkout).
3. Add the `CEFView` library product to your app target.

In your code:

```swift
import AppKit
import CEFView

@main
struct App {
    static func main() {
        let cfg = CEFConfiguration(
            cachePath: FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(Bundle.main.bundleIdentifier!))
        exit(Int32(CEFApplication.run(configuration: cfg) {
            let win = NSWindow(...)
            let webView = CEFWebView(frame: ..., url: URL(string: "https://example.com")!)
            win.contentView = webView
            win.makeKeyAndOrderFront(nil)
        }))
    }
}
```

You also need a sub-process executable target for the helper. The simplest
form (literally one line):

```swift
// HelperApp/main.swift
import CEFView
exit(Int32(CEFApplication.runHelper()))
```

In Xcode: create a second target of type **Command Line Tool**, link the
`CEFView` library, set its bundle identifier to `${PRODUCT_BUNDLE_IDENTIFIER}.helper.shared`
or similar. The Run Script (below) copies this binary into all five helper
slots — you do not create five helper targets.

---

## The Run Script Build Phase

On your host app target → **Build Phases → + → New Run Script Phase**.
Place it **after** "Embed Frameworks" but **before** any code-signing-only
phases.

```sh
"$BUILD_DIR/../../SourcePackages/checkouts/CEFView/scripts/embed-cefview.sh"
```

Required environment variables (Xcode already sets the first three; you set
the rest in the script phase's environment section, OR via "Input Files"
shell vars, OR inline):

| Variable | What |
|---|---|
| `BUILT_PRODUCTS_DIR` | provided by Xcode |
| `PRODUCT_NAME` | provided by Xcode |
| `PRODUCT_BUNDLE_IDENTIFIER` | provided by Xcode |
| `CEFVIEW_FRAMEWORK_PATH` | path to `Chromium Embedded Framework.framework` shipped by the package |
| `CEFVIEW_HELPER_PATH` | path to your built helper Mach-O executable (e.g. `$BUILT_PRODUCTS_DIR/MyAppHelper`) |
| `CEFVIEW_HELPER_PLIST` | `$SRCROOT/../SourcePackages/checkouts/CEFView/scripts/helper.plist.in` |
| `EXPANDED_CODE_SIGN_IDENTITY` | provided by Xcode |

Suggested inline script body:

```sh
PKG="$BUILD_DIR/../../SourcePackages/checkouts/CEFView"
export CEFVIEW_FRAMEWORK_PATH="$PKG/artifacts/CEF.xcframework/macos-arm64/Chromium Embedded Framework.framework"
export CEFVIEW_HELPER_PATH="$BUILT_PRODUCTS_DIR/MyAppHelper"
export CEFVIEW_HELPER_PLIST="$PKG/scripts/helper.plist.in"
"$PKG/scripts/embed-cefview.sh"
```

---

## Codesigning details

The script does the right thing automatically:

- **Framework**: signed with your identity (or ad-hoc `-` in dev).
- **Host app**: signed with your identity *after* helpers + framework are in
  place, so the seal includes them.
- **Helper bundles**: explicitly **not** re-codesigned. Their executables are
  linker-signed at build time and Chromium's IPC handshake validates that
  exact signature byte-for-byte. Re-codesigning the bundle wraps the binary
  in a new signature and breaks the helpers with a `CHECK` fail inside
  `cef_execute_process`.

For Developer ID distribution: set your signing identity in the target's
Signing & Capabilities tab; `EXPANDED_CODE_SIGN_IDENTITY` flows through to
the script automatically.

---

## Entitlements

For hardened runtime / notarization you need a few exception entitlements
because Chromium uses JIT and dlopens the framework:

```xml
<key>com.apple.security.cs.allow-jit</key><true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
```

Add these to your host target's `.entitlements`. **App Sandbox is
incompatible** with CEF in this configuration (Chromium runs its own sandbox)
— do not enable the App Sandbox capability. This means Mac App Store
distribution is not supported.

---

## Dev-only friction

First launch of every freshly-linked binary prompts "Your App wants to use
your confidential information stored in 'Chromium Safe Storage' in your
keychain." Click **Always Allow** once per binary hash. Each recompile
produces a new hash and prompts again — annoying but harmless in dev.

For shipping builds, your stable signing identity gives the binary a stable
identity in the keychain and the prompt only appears once per user per app.
