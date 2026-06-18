import SwiftUI

struct TabRow: View {
    let tab: BrowserTab

    var body: some View {
        HStack(spacing: 6) {
            FaviconView(image: tab.displayFavicon)
            if let webView = tab.webView, webView.observable.isLoading {
                ProgressView().controlSize(.small)
            }
            Text(tab.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            if tab.isHibernated {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tabRow.hibernatedBadge")
            }
        }
        .opacity(tab.isHibernated ? 0.55 : 1)
        .contextMenu {
            if tab.isHibernated {
                Button("Wake up") { tab.wake() }
            } else {
                Button("Hibernate") { tab.hibernate() }
            }
        }
    }
}
