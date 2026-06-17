# Phase 0 — CEF bundle layout (findings)

**CEF**: 144.0.28+ga64d412+chromium-144.0.7559.255 (arm64)
**SDK target**: macOS 12.0
**Built with**: CMake 3.31 + Ninja, Xcode 26.3 toolchain, C++17, `-fno-exceptions -fno-rtti`
**Sandbox**: ON (`CEF_USE_SANDBOX` define; uses Chromium internal sandbox + macOS Seatbelt)

## Final .app structure (confirmed working)
```
cefsimple.app/293M
└── Contents/
    ├── MacOS/cefsimple
    ├── Info.plist
    ├── Resources/English.lproj/MainMenu.nib
    └── Frameworks/
        ├── Chromium Embedded Framework.framework/
        │   ├── Chromium Embedded Framework   (dylib ~200MB)
        │   ├── Libraries/                    (v8 snapshots etc)
        │   ├── Resources/                    (locales, .pak, icudtl.dat)
        │   └── Versions/A/...
        ├── cefsimple Helper.app/             (generic)
        ├── cefsimple Helper (GPU).app/
        ├── cefsimple Helper (Plugin).app/
        ├── cefsimple Helper (Renderer).app/
        └── cefsimple Helper (Alerts).app/   ⚠️ 5 helpers, not 4
```

⚠️ **PLAN.md correction:** CEF 144 ships **5 helpers**, not 4. The Alerts helper handles macOS user notifications.

## Helper Info.plist (template variables)
All 5 helpers share the same plist template (`tests/cefsimple/mac/helper-Info.plist.in`); only the `BUNDLE_ID_SUFFIX` and `EXECUTABLE_NAME` differ:

```
CFBundleIdentifier  = {host-bundle-id}.helper{SUFFIX}   # SUFFIX: "" | .gpu | .plugin | .renderer | .alerts
CFBundleExecutable  = {host-name} Helper{NAME-SUFFIX}
LSUIElement         = true                              # no Dock icon
LSEnvironment.MallocNanoZone = "0"                      # required — Chromium incompatibility
LSMinimumSystemVersion = 12.0
NSSupportsAutomaticGraphicsSwitching = true
```

## Host Info.plist (must-have keys)
```
CFBundleExecutable, CFBundleIdentifier (e.g. org.cef.cefsimple)
NSPrincipalClass = NSApplication
NSMainNibFile    = MainMenu                # cefsimple uses a nib menu
LSEnvironment.MallocNanoZone = "0"
LSMinimumSystemVersion = 12.0
```

## Signing
- CEF binary distribution **does not ship entitlements files** and signs everything **ad-hoc** by default. Sufficient for local dev/spike.
- Production / hardened-runtime needs entitlements (Phase 5):
  - `com.apple.security.cs.allow-jit` — V8 JIT
  - `com.apple.security.cs.allow-unsigned-executable-memory`
  - `com.apple.security.cs.disable-library-validation` — helpers load CEF framework
  - `com.apple.security.cs.allow-dyld-environment-variables` (some helpers)
- Sign order: helpers → framework → host (deepest first).

## Process model (confirmed running)
- 1× main (browser) process: `cefsimple.app/Contents/MacOS/cefsimple`
- N× helper processes spawned from `cefsimple Helper.app/Contents/MacOS/cefsimple Helper` with `--type=gpu-process|utility|renderer|...`
- Helpers receive `--seatbelt-client` arg → macOS sandbox profile.

## Key source files to study for our wrapper
- `tests/cefsimple/cefsimple_mac.mm` — main(), CefInitialize, CefRunMessageLoop
- `tests/cefsimple/process_helper_mac.cc` — helper entry point (CefExecuteProcess)
- `tests/cefsimple/simple_app.{cc,h}` — CefApp implementation
- `tests/cefsimple/simple_handler*.{cc,mm,h}` — CefClient + lifespan + load + display handlers

## Implications for our package
1. **CEF.xcframework** wraps `Chromium Embedded Framework.framework` — straightforward.
2. **libcef_dll_wrapper.a** built in Phase 1 — straightforward, already builds cleanly in our build/.
3. **Helpers** are the friction: 5× `.app` bundles with distinct bundle IDs that must end in `{host}.helper{.suffix}` (Chromium enforces this naming for sandbox). Our SPM package needs to either:
   - (a) ship a single "helper" binary + 5 plist templates, and have a build script generate the 5 `.app` bundles at consumer build time, OR
   - (b) ship 5 prebuilt `.app` bundles inside a resource bundle, and rename bundle IDs at copy time.
   - **(a) is simpler** — the helper binary is small (~50KB, it's just `CefExecuteProcess` wrapper), and we control naming entirely.
4. **No entitlements in spike** — fine for now. Phase 5 ships templates.

## Run confirmation
```
$ open cefsimple.app
$ pgrep -lf cefsimple
71071 cefsimple
71106 cefsimple Helper --type=gpu-process ...
71107 cefsimple Helper --type=utility --utility-sub-type=network.mojom.NetworkService ...
```
✅ Browser + GPU + network service running. Spike works.
