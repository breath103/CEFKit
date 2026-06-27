# HelloChromium

A minimal Xcode project that depends on [ChromiumKit](../..) and shows a
`ChromiumWebView` rendering Hacker News. Structurally identical to what a
third-party project would look like.

```swift
import AppKit
import ChromiumKit

let webView = ChromiumWebView(frame: rect, url: URL(string: "https://news.ycombinator.com")!)
webView.navigationDelegate = self
window.contentView = webView
```

## Run from Xcode

```sh
open HelloChromium.xcodeproj
```

Pick the `HelloChromium` scheme, hit ▶️. First launch will prompt for Keychain
access ("Chromium Safe Storage") — click **Always Allow** once.

## Regenerating the Xcode project

The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonsm/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
```

Commit the generated `.xcodeproj` if you want others to open it without
installing XcodeGen.

## Two targets, two modules

| Target | Module imported | Why |
|---|---|---|
| `HelloChromium` (app) | `import ChromiumKit` | The host. Links the Chromium Embedded Framework at `@executable_path/../Frameworks/...` |
| `HelloChromiumHelper` (tool) | `import ChromiumKitHelper` | The sub-process. Same Mach-O is copied into all 5 helper `.app` bundles by the embed script. Does NOT statically link the framework — `dlopen`s it at runtime via `CefScopedLibraryLoader::LoadInHelper()`. |

If both imported `ChromiumKit`, the helper would inherit a `@executable_path/../Frameworks/...`
load command that's wrong relative to the helper exec (it's three levels
deep inside `HelloChromium.app/Contents/Frameworks/HelloChromium Helper.app/Contents/MacOS/`),
and dyld would refuse to launch it.

## The Run Script Build Phase

The `[ChromiumKit] Embed framework + helpers` build phase calls
[`scripts/embed-chromiumkit.sh`](../../scripts/embed-chromiumkit.sh) which:

1. Assembles 5 helper `.app` bundles from the `HelloChromiumHelper` Mach-O + a
   plist template — distinct bundle IDs (`{host}.helper{|.gpu|.renderer|.plugin|.alerts}`)
2. Skips touching the framework (Xcode auto-embeds it from the `CCEF`
   binary target via the standard SPM build chain) and skips host signing
   (Xcode signs the host itself after the script)

When run outside Xcode (e.g. via `scripts/build-demo.sh`) the same script
does the framework copy + signing too, because no Xcode env vars are set.
