# Prefer `@Observable` over `ObservableObject` + `@Published`

This project targets macOS 14 (see `Examples/HelloChromium/project.yml` and
`Package.swift`), so the Observation framework is available everywhere.
Use the `@Observable` macro for reactive model types — not the legacy
`ObservableObject` / `@Published` / `@ObservedObject` / `@StateObject`
combo.

Why: `@Observable` tracks reads at the property level, so SwiftUI views
re-render only when the property they actually read changes. The Combine
path invalidates the whole view on any `@Published` change. Less code,
fewer property wrappers in views, finer-grained updates.

## ✅

```swift
import Observation

@Observable
final class TabStore {
    var tabs: [BrowserTab] = []
    var selectedID: BrowserTab.ID?
}

struct ContentView: View {
    let store: TabStore   // no wrapper — Observation tracks reads
    var body: some View { ... }
}
```

## ❌

```swift
final class TabStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: BrowserTab.ID?
}

struct ContentView: View {
    @ObservedObject var store: TabStore   // coarse: re-renders on any change
    var body: some View { ... }
}
```

## Carve-outs

- **Combine interop.** If a type genuinely needs `objectWillChange` to
  bridge into a Combine pipeline, `ObservableObject` is fine — say so in
  a one-line comment.
- **Third-party APIs that require `ObservableObject`.** Some libraries
  still take an `ObservableObject`-constrained generic. Wrap, don't fight.
