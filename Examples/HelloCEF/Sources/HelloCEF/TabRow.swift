import SwiftUI

/// Row in the sidebar list. Binds to `webView.observable.*` so the favicon,
/// spinner, and title redraw as CEF state changes.
struct TabRow: View {
    let tab: BrowserTab
    var body: some View {
        HStack(spacing: 6) {
            FaviconView(image: tab.webView.observable.favicon?.image)
            if tab.webView.observable.isLoading {
                ProgressView().controlSize(.small)
            }
            Text(tabLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var tabLabel: String {
        let title = tab.webView.observable.title
        if let title, !title.isEmpty { return title }
        return tab.webView.observable.url?.host ?? "new tab"
    }
}
