import ChromiumKit
import Foundation
import Observation

/// In-flight JS dialog routed up from a `ChromiumWebView` so ContentView can
/// render it as a SwiftUI sheet. `respond` MUST be called exactly once.
@Observable
final class PendingDialog: Identifiable {
    enum Kind {
        case alert
        case confirm
        case prompt(defaultText: String)
    }

    let id = UUID()
    let kind: Kind
    let message: String
    let origin: URL?
    var promptText: String
    let respond: (Response) -> Void

    enum Response: Equatable {
        case ok
        case okWithText(String)
        case cancel
    }

    init(kind: Kind, message: String, origin: URL?, respond: @escaping (Response) -> Void) {
        self.kind = kind
        self.message = message
        self.origin = origin
        self.respond = respond
        promptText = if case let .prompt(defaultText) = kind { defaultText } else { "" }
    }
}

@Observable
final class TabStore: NSObject {
    var tabs: [BrowserTab] = []
    var pendingDialog: PendingDialog?

    var selectedID: BrowserTab.ID? {
        didSet { selectedTab?.wake() }
    }

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedID }
    }

    func newTab(_ url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(url: url)
        tab.navigationDelegate = self
        tab.uiDelegate = self
        tabs.append(tab)
        selectedID = tab.id
    }
}

extension TabStore: ChromiumNavigationDelegate {
    func webView(
        _: ChromiumWebView,
        requestsNewTabFor url: URL?,
        userGesture _: Bool,
        disposition: CEFTabDisposition
    ) -> ChromiumWebView? {
        let shell = ChromiumWebView.popupView()
        let target = url ?? URL(string: "about:blank")!
        let tab = BrowserTab(adopting: shell, targetURL: target)
        tab.navigationDelegate = self
        tab.uiDelegate = self
        tabs.append(tab)
        if disposition == .newForegroundTab {
            selectedID = tab.id
        }
        return shell
    }
}

extension TabStore: ChromiumUIDelegate {
    func webView(
        _: ChromiumWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        originURL: URL?,
        completionHandler: @escaping () -> Void
    ) {
        pendingDialog = PendingDialog(kind: .alert, message: message, origin: originURL) { [weak self] _ in
            completionHandler()
            self?.pendingDialog = nil
        }
    }

    func webView(
        _: ChromiumWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        originURL: URL?,
        completionHandler: @escaping (Bool) -> Void
    ) {
        pendingDialog = PendingDialog(kind: .confirm, message: message, origin: originURL) { [weak self] response in
            completionHandler(response == .ok)
            self?.pendingDialog = nil
        }
    }

    func webView(
        _: ChromiumWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        originURL: URL?,
        completionHandler: @escaping (String?) -> Void
    ) {
        pendingDialog = PendingDialog(
            kind: .prompt(defaultText: defaultText ?? ""),
            message: prompt,
            origin: originURL
        ) { [weak self] response in
            switch response {
            case let .okWithText(text): completionHandler(text)
            case .ok: completionHandler("")
            case .cancel: completionHandler(nil)
            }
            self?.pendingDialog = nil
        }
    }
}
