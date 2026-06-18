# `target="_blank"` → new tab (opener preserved)

## Problem

Today CEF's `OnBeforePopup` is not overridden. The default returns `false`,
which means CEF spawns its own popup browser — a detached child with no UI
chrome and no integration with HelloCEF's `TabStore`. `target="_blank"` clicks
and `window.open(...)` calls effectively get lost.

## Goal

`target="_blank"` → new tab in HelloCEF. `cmd+click` → background tab. The
new tab's `window.opener` references the opener page; `window.open(...)` in the
opener returns a usable `WindowProxy`. Cross-tab `postMessage` works.

`window.open(...)` with a feature string (real popup) is **out of scope** for
this PR — leaves CEF default behavior. Follow-up issue.

## CEF mechanics — why opener preservation requires "allow"

`OnBeforePopup` returns a `bool`:

| Return | Outcome |
|--------|---------|
| `true` (cancel) | CEF aborts the popup. The opener's `window.open(...)` returns `null`. `window.opener` in the (cancelled) new window is null. |
| `false` (allow) | CEF creates the popup browser within the same renderer process group as the opener. Blink wires up the opener relationship. |

So we can't "cancel and reopen in our own tab" — the opener is lost the moment
we cancel. We must allow the popup AND redirect where it lands. Both are
controllable in the same callback:

```cpp
bool OnBeforePopup(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    int popup_id,
    const CefString& target_url,
    const CefString& target_frame_name,
    WindowOpenDisposition target_disposition,
    bool user_gesture,
    const CefPopupFeatures& popupFeatures,
    CefWindowInfo& windowInfo,       // <-- mutate: where to host the new browser
    CefRefPtr<CefClient>& client,    // <-- replace: which client gets OnAfterCreated
    CefBrowserSettings& settings,
    CefRefPtr<CefDictionaryValue>& extra_info,
    bool* no_javascript_access) override;
```

By mutating `windowInfo` to point at an NSView we control and replacing
`client` with a fresh `_CEFClient` bound to our new `CEFView`, we direct the
popup browser into our tab UI while Chromium still treats it as "allowed" and
preserves the opener relationship.

## Disposition dispatch table

`target_disposition` differentiates the kinds of popup. The PR handles two:

| Disposition | Behavior | Selected? |
|-------------|----------|-----------|
| `WOD_NEW_FOREGROUND_TAB` | `target="_blank"` click; cmd+shift+click | New tab, foreground |
| `WOD_NEW_BACKGROUND_TAB` | cmd+click | New tab, background |
| `WOD_NEW_POPUP` | `window.open(url, name, "width=...")` | **Leave CEF default. Follow-up.** |
| `WOD_NEW_WINDOW` | `target="_blank"` with `rel=noopener` (sometimes) | Same as NEW_POPUP for now. |
| other | rare (save, current_tab, etc.) | Don't touch — return default. |

## Architecture

### Three new pieces

1. **Shell-mode `CEFView` initializer** (`CEFViewObjC`). Creates the NSView and
   the `_CEFClient` upfront, but does NOT call `CefBrowserHost::CreateBrowser`.
   `viewDidMoveToWindow` skips its usual create step when shell-mode is set.
   The browser arrives via `_CEFClient::OnAfterCreated` once CEF spawns the
   popup. From the consumer side everything else is identical — `load`,
   `goBack`, etc. already null-guard via `_client->browser()`.

2. **`OnBeforePopup` override** (`_CEFClient` in `CEFView.mm`). Runs on the
   CEF UI thread = NSApp main thread (Chromium uses cocoa main runloop via
   `CefRunMessageLoop`), so we can call into AppKit / our delegate directly.
   Dispatch on `target_disposition`. For TAB dispositions:
   - Call `[delegate webView:self requestsNewTabForURL:userGesture:disposition:]`
     synchronously. Delegate returns a shell `CEFView`.
   - `windowInfo.SetAsChild((__bridge void*)shell, ...)`.
   - `client = shell.internalClient` (need a new private getter on `CEFView`).
   - Return `false`.

3. **Delegate hook** (`CEFNavigationDelegate` in `include/CEFViewObjC.h`,
   bridged through `CEFKit`). New optional method:
   ```objc
   - (CEFView* _Nullable)webView:(CEFView*)opener
       requestsNewTabForURL:(NSURL*)url
       userGesture:(BOOL)userGesture
       disposition:(CEFTabDisposition)disposition;
   ```
   Returning `nil` falls back to CEF's default popup behavior. Returning a
   shell `CEFView` claims the popup.

### Parent NSView wrinkle

`windowInfo.SetAsChild(NSView*, rect)` works even when the parent NSView is
not yet in a window. CEF creates its browser NSView inside the parent in
memory; rendering activates when AppKit hosts the parent in a window. SwiftUI
mounts the new tab via the existing ZStack, which fires
`viewDidMoveToWindow` on the shell — at which point CEF's browser NSView
inherits a real window and starts rendering. No re-parenting needed.

## HelloCEF wiring

- `TabStore.newEmptyTab() -> BrowserTab` — returns a tab whose `webView` is a
  shell. Snapshot URL is the target URL (so the row's title fallback isn't
  empty).
- `AppDelegate.webView(_:requestsNewTabFor:userGesture:disposition:)` — calls
  `store.newEmptyTab(...)`, sets `store.selectedID = newTab.id` if foreground.
- `BrowserTab` already supports `webView: CEFWebView?`; shell mode just means
  webView is a CEFView that hasn't received its browser yet.

## Verification

`TargetBlankUITests`:
- Programmatically load a `data:text/html` URL with `<a id=link target=_blank href=https://example.com>open</a>` in the active tab.
- Click the link via XCUITest (or by `evaluateJavaScript("document.getElementById('link').click()")`).
- Assert `app.outlines.firstMatch.outlineRows.count == 3` (was 2).
- On the new tab, `evaluateJavaScript("typeof window.opener")` returns `"object"`.
- `evaluateJavaScript("window.opener.location.origin === window.location.origin")`
  — same-origin in the fixture, so true.

## Risks

- **Delegate returns nil mid-flow.** Fall back: return `false` from
  `OnBeforePopup` without mutating windowInfo/client → CEF creates its own
  popup window (today's behavior). No regression, just no integration.
- **Shell CEFView mounted before browser arrives.** `load(_:)` etc. no-op
  via `_browser` null guard; the URL is queued nowhere. Acceptable: the popup
  is CEF-initiated, it'll navigate to `target_url` on its own.
- **Same-origin cross-tab JS could leak references after we tear down the
  child tab.** Standard browser semantics — opener WindowProxy becomes
  "closed" when the popup closes. CEFView.dealloc closes the browser cleanly
  via `OnBeforeClose`; opener stays valid until then.

## Out of scope

- `window.open(url, name, "width=400,height=300,...")` — real popup with a
  feature string. `target_disposition` is `WOD_NEW_POPUP`. PR2 follow-up.
- DevTools popups (already separately handled via `OnBeforeDevToolsPopup`).
- Beforeunload prompts on the opener when the popup wins focus.
