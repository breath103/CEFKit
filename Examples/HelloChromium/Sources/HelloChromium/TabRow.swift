import SwiftUI

struct TabRow: View {
    let tab: TabRecord
    @Environment(TabRuntime.self) private var runtime

    var body: some View {
        let webView = runtime.liveWebView(for: tab)
        let awake = webView != nil
        HStack(spacing: 6) {
            FaviconView(image: tab.displayFavicon)
            if let webView, webView.observable.isLoading {
                ProgressView().controlSize(.small)
            }
            Text(tab.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            if !awake {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tabRow.hibernatedBadge")
            }
        }
        .opacity(awake ? 1 : 0.55)
        .contextMenu {
            if awake {
                Button("Hibernate") { runtime.hibernate(tab) }
            } else {
                Button("Wake up") { runtime.wake(tab) }
            }
        }
    }
}
