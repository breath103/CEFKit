import SwiftUI

struct AddressBar: View {
    let tab: BrowserTab?
    var body: some View {
        HStack(spacing: 8) {
            Button { tab?.webView.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(tab?.webView.observable.canGoBack != true)
                .help("Back")
            Button { tab?.webView.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(tab?.webView.observable.canGoForward != true)
                .help("Forward")
            if tab?.webView.observable.isLoading == true {
                Button { tab?.webView.stopLoading() } label: { Image(systemName: "xmark") }
                    .help("Stop")
            } else {
                Button { tab?.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(tab == nil)
                    .help("Reload")
            }
            FaviconView(image: tab?.webView.observable.favicon?.image)
            Text(tab?.webView.observable.url?.absoluteString ?? "")
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(Divider(), alignment: .bottom)
    }
}
