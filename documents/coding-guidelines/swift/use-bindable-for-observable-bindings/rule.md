# Use `@Bindable` to derive bindings from `@Observable` types

When a SwiftUI view needs a two-way `Binding` to a property of an
`@Observable` model, declare the property with `@Bindable` and write
`$model.property`. Do not hand-roll a `Binding(get:set:)` closure pair.

Why: `@Bindable` is the official bridge. `Binding(get:set:)` works but
is verbose, easy to get wrong (read/write asymmetry, missed property
paths), and signals "I didn't know the API." Reviewers will reach for
the wrapper anyway — start there.

## ✅

```swift
struct ContentView: View {
    @Bindable var store: TabStore   // TabStore is @Observable

    var body: some View {
        List(selection: $store.selectedID) { ... }
    }
}
```

## ❌

```swift
struct ContentView: View {
    let store: TabStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedID },
            set: { store.selectedID = $0 }
        )) { ... }
    }
}
```

## Carve-outs

- **Computed / derived bindings.** When the binding's get or set has
  real logic (clamp, transform, fan-out to two properties), a manual
  `Binding(get:set:)` is the right tool — there's no `@Bindable` for it.
- **Read-only views.** If the view only reads `store.x` and never needs
  a binding, plain `let store: TabStore` is fine; don't add `@Bindable`
  for show.
