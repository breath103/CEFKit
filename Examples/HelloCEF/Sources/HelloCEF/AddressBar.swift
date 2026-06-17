import SwiftUI

struct AddressBar: View {
    let tab: BrowserTab?

    @FocusState private var fieldFocused: Bool
    @State private var editText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Button { tab?.webView?.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(tab?.webView?.observable.canGoBack != true)
                .help("Back")
            Button { tab?.webView?.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(tab?.webView?.observable.canGoForward != true)
                .help("Forward")
            if tab?.webView?.observable.isLoading == true {
                Button { tab?.webView?.stopLoading() } label: { Image(systemName: "xmark") }
                    .help("Stop")
            } else {
                Button { tab?.webView?.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(tab?.webView == nil)
                    .help("Reload")
            }

            centerArea
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(Divider(), alignment: .bottom)
    }

    /// ZStack with both states always mounted: TextField needs to be in the
    /// hierarchy when fieldFocused flips to true, otherwise @FocusState has
    /// nothing to focus. We toggle opacity / hit-testing to swap which is
    /// visible and interactive.
    private var centerArea: some View {
        ZStack {
            TextField("Search or enter URL", text: $editText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .focused($fieldFocused)
                .onSubmit { navigate(to: editText) }
                .onExitCommand { fieldFocused = false }
                .opacity(fieldFocused ? 1 : 0)
                .allowsHitTesting(fieldFocused)
                .accessibilityIdentifier("addressBar.field")

            Button {
                editText = tab?.displayURL.absoluteString ?? ""
                fieldFocused = true
            } label: {
                HStack(spacing: 6) {
                    FaviconView(image: tab?.displayFavicon)
                    Text(tab?.displayTitle ?? "")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(tab == nil)
            .opacity(fieldFocused ? 0 : 1)
            .allowsHitTesting(!fieldFocused)
            .accessibilityIdentifier("addressBar.display")
        }
    }

    private func navigate(to raw: String) {
        guard let tab else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme) else { return }
        if tab.isHibernated {
            // Wake with the target URL directly so the new CEFWebView starts
            // loading where the user is going, not the stale snapshot.
            tab.wake(loading: url)
        } else {
            tab.webView?.load(url)
        }
        fieldFocused = false
    }
}
