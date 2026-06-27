# One top-level type per file, named after it

A Swift file declares exactly one top-level type, and the filename matches
that type. `BrowserTab.swift` declares `BrowserTab`; `AddressBar.swift`
declares `AddressBar`. Companion extensions on the same type stay in the
file; unrelated types get their own.

Why: a grab-bag file (everything in `main.swift`) hides what lives where
and makes diffs noisy. One-type-per-file keeps the directory listing
honest — the file you open is the type you wanted, no scrolling past
unrelated declarations to find it.

## Carve-outs

- **Entry points.** `main.swift` is allowed to declare top-level
  statements (`let delegate = ...`, `exit(...)`) instead of a type — but
  it should declare **no** top-level types. Move them to siblings.
- **Tightly coupled helpers.** A small private `struct`/`enum` used only
  inside the file's main type may live alongside it (e.g. a config
  struct, a private state enum). If it's reused elsewhere, extract.
- **Closely paired model + store.** A `Foo` and its `FooStore` can share
  a file when one is meaningless without the other and both are small
  (<~30 lines combined). Split once either grows.

## ✅

```swift
// BrowserTab.swift
final class BrowserTab: Identifiable { ... }
final class TabStore: ObservableObject { ... }   // paired, both small
```

```swift
// AddressBar.swift
struct AddressBar: View { ... }
```

```swift
// main.swift — entry point only
let delegate = AppDelegate()
exit(Int32(ChromiumApplication.run(configuration: config) { ... }))
```

## ❌

```swift
// main.swift — everything in one file
final class BrowserTab { ... }
final class TabStore { ... }
struct TabRow: View { ... }
struct FaviconView: View { ... }
struct AddressBar: View { ... }
struct ContentView: View { ... }
final class AppDelegate { ... }
let delegate = AppDelegate()
exit(...)
```
