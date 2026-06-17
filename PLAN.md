# CEFKit — CEF-backed WebView for macOS, distributed via SPM

Goal: a Swift package that exposes a `CEFKit` (NSView/SwiftUI) you `import CEFKit` and drop in like `WKWebView`, backed by a precompiled Chromium Embedded Framework binary.

---

## 1. Background: how CEF differs from WKWebView

WKWebView is one class. CEF is a **multi-process** framework with strict packaging requirements on macOS:

- **Main app** links `Chromium Embedded Framework.framework` (the CEF dylib + Chromium resources).
- **Helper apps** — 4 separate `.app` bundles (`Helper`, `Helper (GPU)`, `Helper (Plugin)`, `Helper (Renderer)`) embedded under `Contents/Frameworks/`. Each must have its own bundle ID and the right `Info.plist` entitlements (JIT, allow-unsigned-executable-memory, disable-library-validation).
- **CEF wrapper** (`libcef_dll_wrapper`) — C++ static lib you build yourself from CEF sources; bridges the C API.
- **Code signing** — every helper + the framework must be signed; hardened runtime needs specific entitlements or Chromium's sandbox/JIT will crash.

This is the part that makes "just import CEFKit" hard. The package has to ship the framework, the helper apps, and a build-phase script that copies + re-signs them into the consumer's app bundle.

---

## 2. Architecture

```
┌─────────────────────────────────────────────┐
│ Consumer macOS app (Xcode)                  │
│   import CEFKit                            │
│   CEFKit(url:)  ← SwiftUI / NSViewRep      │
└──────────────┬──────────────────────────────┘
               │ SPM dependency
┌──────────────▼──────────────────────────────┐
│ Package: CEFKit                            │
│  ├─ CEFKit         (Swift, public API)     │
│  ├─ CEFViewObjC     (Obj-C++ glue)          │
│  ├─ CEFWrapper      (C++ libcef_dll_wrapper)│
│  ├─ CCEF            (binaryTarget .xcframe) │ ← Chromium Embedded Framework.framework
│  └─ CEFHelpers      (binaryTarget .xcframe) │ ← 4 helper .apps zipped
│     + Plugin: CEFEmbed (build tool plugin)  │ ← copies + signs into host .app
└─────────────────────────────────────────────┘
```

Key decisions:

- **Distribute CEF as `binaryTarget` XCFrameworks** hosted on GitHub Releases (URL + checksum in `Package.swift`). Source CEF is ~1GB; binary is ~200MB. SPM handles download + cache.
- **Helpers can't ship as a framework** — they're `.app` bundles. Wrap them in an XCFramework-shaped zip and have the build-tool plugin extract + embed them. Or ship as `.bundle` resources and rename at copy time.
- **Public API is pure Swift**, mirroring `WKWebView` shape: `load(_:)`, `loadHTMLString`, `goBack`, `reload`, `evaluateJavaScript`, navigation delegate, message handlers.
- **Obj-C++ layer** owns the `CefBrowser` ref and bridges `CefClient`/`CefLifeSpanHandler`/`CefLoadHandler` callbacks back to Swift via a protocol.
- **One process model**: standard CEF multi-process (not single-process — Chromium drops single-process support periodically and it's not sandbox-compatible).

---

## 3. Phased plan

### Phase 0 — Spike: get CEF running in a plain Xcode app
- [ ] Download CEF binary distribution for macOS (arm64 + x86_64) from https://cef-builds.spotifycdn.com/index.html
- [ ] Open `cefclient`/`cefsimple` sample in Xcode, build, run. Confirm it loads a page.
- [ ] Read `tests/cefsimple/cefsimple_mac.mm` end-to-end — that's the minimum viable host.
- [ ] Document the exact bundle layout, plist keys, entitlements, and signing commands that worked.

**Exit criteria:** a hand-built `.app` that shows google.com via CEF, runs sandboxed, passes `codesign --verify --deep --strict`.

### Phase 1 — Build libcef_dll_wrapper + first reusable framework
- [ ] CMake build `libcef_dll_wrapper` for `arm64` and `x86_64`, both Debug and Release.
- [ ] Lipo into universal static lib.
- [ ] Script the whole thing (`scripts/build-wrapper.sh`) so it's reproducible.
- [ ] Wrap `Chromium Embedded Framework.framework` into an XCFramework: `xcodebuild -create-xcframework -framework ... -output CEF.xcframework`.

### Phase 2 — Swift package skeleton
- [ ] `swift package init`. Add targets per the architecture diagram.
- [ ] `CCEF` binaryTarget pointing at a GitHub release zip + sha256.
- [ ] `CEFWrapper` C++ target with `cxxSettings` for C++17, header search paths into CEF includes.
- [ ] `CEFViewObjC` Obj-C++ target depending on `CEFWrapper` + `CCEF`.
- [ ] `CEFKit` Swift target depending on `CEFViewObjC`.
- [ ] Verify `swift build` succeeds on a stub that just calls `CefInitialize`/`CefShutdown`.

### Phase 3 — Public API
- [ ] `CEFKit: NSView` with `load(URLRequest)`, `loadHTMLString(_:baseURL:)`, `goBack`, `goForward`, `reload`, `stopLoading`, `evaluateJavaScript(_:completionHandler:)`.
- [ ] `CEFWebViewRepresentable: NSViewRepresentable` for SwiftUI.
- [ ] `CEFNavigationDelegate` protocol mirroring `WKNavigationDelegate` essentials.
- [ ] `CEFConfiguration` (user agent, cache path, locale, command-line switches).
- [ ] One-shot `CEF.bootstrap()` that calls `CefInitialize` on first use; `CefDoMessageLoopWork` integration with `NSRunLoop` via external pump (use `CefSettings.external_message_pump = true` + a CVDisplayLink or `CFRunLoopTimer`).

### Phase 4 — The hard part: helpers + embedding
- [ ] Build the 4 helper apps from CEF's `cef_helper` target. Sign each with the right entitlements plist.
- [ ] Ship helpers as a resource bundle inside the package OR as a second XCFramework-shaped artifact.
- [ ] **SPM build-tool plugin** (`CEFEmbed`) that runs in the consumer's build:
  - Copies `Chromium Embedded Framework.framework` to `Contents/Frameworks/`.
  - Copies each helper `.app` to `Contents/Frameworks/`.
  - Re-signs them with the consumer's signing identity (read from `$EXPANDED_CODE_SIGN_IDENTITY`).
  - Patches helper `Info.plist` bundle IDs to be `{consumer-bundle-id}.helper(.gpu|.plugin|.renderer)`.
- [ ] **Caveat:** SPM build-tool plugins have limited access to the final `.app` bundle. May need to fall back to a `.xcconfig` + Run Script Phase that consumers add manually. Document both paths.

### Phase 5 — Entitlements + signing docs
- [ ] Ship a `CEFKit.entitlements` template the consumer merges into their app entitlements (JIT, allow-unsigned-executable-memory, disable-library-validation, hardened runtime exceptions).
- [ ] README section: notarization gotchas (helpers must be notarized separately or as part of the host app submission).

### Phase 6 — Distribution
- [ ] GitHub Actions: matrix build (arm64, x86_64) → assemble XCFrameworks → compute sha256 → create Release → update `Package.swift` URL/checksum.
- [ ] Tag CEF version in package version (e.g. `0.1.0-cef.124.3`).
- [ ] Example consumer app in `Examples/Demo` that consumes the package via SPM (not path) — proves end-to-end install works.

### Phase 7 — Polish
- [ ] DevTools open/close API.
- [ ] Cookie store API.
- [ ] Custom URL scheme handlers (CEF `CefResourceRequestHandler`).
- [ ] Off-screen rendering mode (optional — for SwiftUI compositing into Metal layers).

---

## 4. Open questions / risks

- **SPM + .app bundles inside binaryTarget**: SPM's binaryTarget only officially supports `.xcframework`. Helpers being `.app`s means we may need a creative wrapper (zip as resource, extract at build time) or require consumers to add a Run Script. **Validate in Phase 4 spike before committing.**
- **Sandbox**: CEF on macOS uses Chromium's own sandbox. App Sandbox entitlement interacts poorly — most CEF apps disable App Sandbox. Document this; it blocks Mac App Store distribution for consumers.
- **Binary size**: ~200MB per arch. Universal XCFramework ~400MB. Consider arm64-only as default with x86_64 as separate package.
- **CEF release cadence**: Chromium updates every ~4 weeks. Need automation to rebuild + republish, or pin to LTS-ish versions.
- **Symbol visibility**: `libcef_dll_wrapper` is C++; can't expose to Swift directly. Obj-C++ shim is mandatory.

---

## 5. Reference projects to study

- `chromiumembedded/cef` → `tests/cefsimple` and `tests/cefclient` (canonical macOS host).
- `CEFswift` (older Swift binding, archived but instructive).
- Brave/Electron/CEFSharp build scripts for signing + helper packaging patterns.
- `swift-package-manager` docs on `binaryTarget` and build-tool plugins.

---

## 6. Immediate next actions (this week)

1. Download CEF arm64 binary distribution for current stable.
2. Build + run `cefsimple` from the Xcode project it ships with. Take notes on bundle layout.
3. Build `libcef_dll_wrapper` standalone via CMake.
4. Stand up empty `CEFKit` SwiftPM package with `CCEF` binaryTarget pointing at a locally-hosted zip; confirm `swift build` resolves.

Stop after step 4 and re-evaluate Phase 4 plugin feasibility before going further.
