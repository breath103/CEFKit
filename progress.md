# CEFKit — Progress Tracker

**Rule:** update this file after every meaningful step. Check boxes as we go. If a step is blocked, write WHY inline.

**Note:** Mac App Store distribution is NOT a goal. We can freely disable App Sandbox and use whatever entitlements CEF needs.

---

## Phase 0 — Spike: hand-built CEF app ✅
- [x] Pick CEF version → **144.0.28+ga64d412+chromium-144.0.7559.255**
- [x] Download arm64 macOS binary distribution → `vendor/cef/`
- [x] Extract; locate `tests/cefsimple`
- [x] Build cefsimple (CMake+Ninja, not Xcode generator)
- [x] Run cefsimple; confirmed processes spawn (browser + GPU + network)
- [x] Document bundle layout → `notes/phase0-bundle-layout.md`
- [x] Document entitlements + plist keys used (ad-hoc signing for spike; prod entitlements deferred to Phase 5)
- [N/A] codesign commands — CEF binary distro signs ad-hoc; consumer will need real signing

**Findings:**
- 5 helpers, not 4 (Alerts is new). PLAN.md needs correction.
- Helper bundle ID pattern: `{host}.helper{.gpu|.plugin|.renderer|.alerts}` (suffix empty for generic).
- Single helper binary can serve all 5 — only plist + bundle name differ.
- This simplifies Phase 4: ship 1 helper binary + 5 plist templates, generate bundles at consumer build time.

## Phase 1 — CEF.xcframework + wrapper source plan ✅
- [x] Wrap `Chromium Embedded Framework.framework` as `artifacts/CEF.xcframework` (arm64, 289MB)
- [x] Build script `scripts/build-cef-artifacts.sh`
- [DEFERRED] x86_64 slice → Phase 6 (cross-arch via separate macosx64 tarball, lipo at xcframework stage)
- [DECISION] libcef_dll_wrapper ships as **source** in SwiftPM C++ target (not prebuilt .a). Simpler, consumers already have C++ toolchain via Xcode. libcef_dll_wrapper sources live in `vendor/cef/libcef_dll/` + headers in `vendor/cef/include/`.

## Phase 2 — SwiftPM skeleton ✅
- [x] `Package.swift` written (4 targets: CCEF binaryTarget, CEFWrapper C++, CEFViewObjC Obj-C++, CEFKit Swift)
- [x] CEF headers + libcef_dll vendored into `Sources/CEFWrapper/`
- [x] Obj-C++ stub `CEFBootstrap.mm` references CEF version constant → proves header chain works
- [x] Swift stub `CEF.isAvailable` calls into ObjC layer → proves cross-language wiring
- [x] `swift build` → **Build complete!** (warnings suppressed via -Wno-undefined-var-template)
- [BLOCKED-by-Phase-4] `swift test` fails at dlopen time — xctest bundle has no `Frameworks/` directory and binaryTarget framework isn't auto-embedded. This is the embedding problem Phase 4 solves; not a regression. Build chain itself is correct.

**Decision recap:**
- Single C++ target compiles libcef_dll wrapper sources in-tree (~5MB output)
- CCEF.xcframework only contains the prebuilt Chromium framework
- ObjC++ glue layer is the bridge Swift imports from

## Phase 3 — Public API ✅
- [x] Demo.app proves full embedding chain (screenshot demo-shot2.png, then swift-final.png)
- [x] AppleScript screenshot helper
- [x] Public ObjC surface with NS_SWIFT_NAME → Swift sees `CEFApplication`, `CEFWebView`, `CEFConfiguration`, `CEFNavigationDelegate`
- [x] Methods: `load(_:)`, `loadHTMLString(_:baseURL:)`, `reload`, `reloadFromOrigin`, `stopLoading`, `goBack`, `goForward`, `evaluateJavaScript(_:completion:)`
- [x] Properties: `URL`, `title`, `canGoBack`, `canGoForward`, `isLoading`, `navigationDelegate`
- [x] `CEFConfiguration` (userAgent, locale, cachePath, sandboxDisabled) applied to `CefSettings`
- [x] `CEFNavigationDelegate` protocol: didStart / didFinish(statusCode) / didFail / didChangeTitle / didChangeLoadingState — all wired through `CefLoadHandler` + `CefDisplayHandler`
- [x] `CEFApplication.run(configuration:setup:)` (no-arg argc/argv via `_NSGetArgv`)
- [x] **Swift extension `CEFWebView+Swift.swift`**: typed `evaluateJavaScript<T:Decodable>(_:as:) async throws -> T` (DevTools RemoteObject unwrap + JSON re-encode → JSONDecoder)
- [x] `CEFConfiguration` Swift convenience init
- [x] Swift demo `demo_main.swift` consumes ONLY the Swift API — verified live, page loaded, window title swapped via delegate, 5 helpers + 2 renderers spawned
- [ ] `CEFWebViewRepresentable` for SwiftUI — deferred (per user: "much later")
- [ ] External message pump (CefDoMessageLoopWork) for SwiftUI App lifecycle — deferred

### Known dev-only friction
First launch of every freshly-linked binary prompts "Demo wants to use Chromium Safe Storage in your keychain" — clicking **Always Allow** persists for that binary hash. Recompile = new hash = new prompt. Bypassing via `--use-mock-keychain` programmatically is possible but messy (must inject before CefMainArgs is constructed); not worth the complexity for now per user direction.

### ~~RUNTIME REGRESSION~~ — RESOLVED
The earlier hang in `CefInitialize` was the **keychain prompt blocking the main thread**, not any code issue. Visible once we stopped redirecting stdout long enough to surface the dialog.
Symptom: `CefInitialize` spawns only GPU+Network helpers; they self-terminate after 15s with
`Terminating current process after 15 seconds with no connection` (chrome_debug.log).
Renderer never spawns, setup block never fires, no window.

cefsimple in same env still works fine (5 helpers + 2 renderers), proving environment is OK.
Bisection narrowed the regression to **our compiled binary**, even when:
- Using the CMake-built libcef_dll_wrapper.a (same as cefsimple uses)
- Using cefsimple's own helper binaries
- Dropping our binary into cefsimple's exact bundle layout
- With/without `settings.no_sandbox = true`
- With/without `settings.root_cache_path`
- Stripping diagnostics back to a minimal CEFApplication.mm

The hang is inside `cef_initialize` → `cef_dump_without_crashing_unthrottled` per `sample`.
Likely cause: subtle compile-flag or symbol-visibility mismatch between our compiled
CEFApplication.mm/CEFKit.mm and what CEF expects. To investigate fresh:
1. Diff link commands between cefsimple (which works) and our demo (which doesn't): `otool -L`, `nm | grep CEF`
2. Try linking our .mm files with `-fno-objc-arc` (cefsimple uses manual refcounting; CEF mixes both poorly?)
3. Bisect by stripping our CEFKit's _CEFClient → CefClient-only inheritance
4. Compare CefMainArgs argv with cefsimple's at the exact moment they're constructed

## Phase 4 — Helpers + embedding ✅
- [x] Reusable `scripts/embed-cefview.sh` — single source of truth for embedding
  (host build-demo.sh AND downstream Xcode consumers invoke the same script)
- [x] Helper plist template promoted to `scripts/helper.plist.in`
- [x] Documented codesign rules: framework + host signed with consumer identity,
  helpers **never** re-codesigned (linker-signed binary is what Chromium IPC validates)
- [x] `INTEGRATION.md` — full Xcode integration walkthrough
- [x] build-demo.sh refactored to delegate to embed-cefview.sh; smoke-tested
  (5 helpers + 2 renderers + 1 window)
- [ ] Sandbox Distribution wiring (re-enable Chromium sandbox) — deferred to Phase 5

## Phase 4 — Helpers + embedding (RISKIEST)
- [ ] Build all 4 helper apps
- [ ] Decide: build-tool plugin vs documented Run Script Phase
- [ ] Implement chosen embedding mechanism
- [ ] Re-sign with consumer identity
- [ ] Patch helper bundle IDs to `{host}.helper(.gpu|.plugin|.renderer)`

## Phase 5 — Entitlements docs
- [ ] Ship `CEFKit.entitlements` template
- [ ] README: signing + notarization

## Phase 6 — Distribution
- [ ] GitHub Actions matrix build
- [ ] GitHub Release with checksummed artifacts
- [ ] `Examples/Demo` consumes via SPM URL
- [ ] End-to-end: clean machine, `swift build`, runs

## Phase 7 — Polish
- [ ] DevTools API
- [ ] Cookie store
- [ ] Custom URL scheme handlers
- [ ] OSR mode (optional)

---

## Log

(append dated entries here as we work — keep terse)

- **2026-06-17**: PLAN.md written. progress.md created. Starting Phase 0.
