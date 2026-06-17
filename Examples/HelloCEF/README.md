# HelloCEF

A minimal standalone consumer of the [CEFKit](../..) package. Structurally
identical to what a third-party project would look like — its `Package.swift`
declares CEFKit as a dependency, and the source code only ever talks to
`CEFKit` and `CEFKitHelper`.

```swift
import AppKit
import CEFKit

let webView = CEFWebView(frame: rect, url: URL(string: "https://news.ycombinator.com")!)
webView.navigationDelegate = self
window.contentView = webView
```

## Build & run

```sh
./build.sh
open build/HelloCEF.app
```

First launch: click **Always Allow** on the Keychain prompt. See the root
README for why.

## Why two targets

CEF runs as five separate `.app` bundles (helpers) embedded in the host
app's `Contents/Frameworks/`. We need two distinct executables:

| Target | Module imported | Why |
|---|---|---|
| `HelloCEF` | `import CEFKit` | The host. Pulls in the Chromium Embedded Framework as a linked binary at `@executable_path/../Frameworks/...` |
| `HelloCEFHelper` | `import CEFKitHelper` | The sub-process. The same Mach-O is copied into all 5 helper `.app` bundles. Does NOT statically link the framework — it `dlopen`s it at runtime via `CefScopedLibraryLoader::LoadInHelper()`, which finds it relative to the host bundle (not the helper bundle). |

If both used `import CEFKit`, the helper would inherit a load command for
`@executable_path/../Frameworks/Chromium Embedded Framework.framework/...`
which is wrong relative to the helper exec — that path doesn't exist three
levels deep inside `HelloCEF.app/Contents/Frameworks/HelloCEF Helper.app/Contents/MacOS/`,
and dyld would refuse to launch the helper.

## What `build.sh` does

1. `swift build -c release` → produces `HelloCEF` and `HelloCEFHelper`
   executables in `.build/`
2. Assembles a `HelloCEF.app` shell with `Contents/MacOS/HelloCEF` and the
   `Info.plist`
3. Runs `../../scripts/embed-cefkit.sh` to copy the framework + assemble
   the 5 helper `.app` bundles + sign

In an Xcode project, step 3 is the entire integration — a Run Script Build
Phase that calls `embed-cefkit.sh`. The rest is normal Xcode plumbing.
See [`../../INTEGRATION.md`](../../INTEGRATION.md).
