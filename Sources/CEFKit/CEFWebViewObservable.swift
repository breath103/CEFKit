@_exported import CEFViewObjC
import AppKit
import Foundation
import Observation

/// `@Observable` mirror of `CEFWebView`'s reactive state, for SwiftUI binding.
///
/// The truth lives on the `CEFWebView` itself (the underlying ObjC `@property`s
/// fire KVO when CEF callbacks land). This class observes those KVO keys and
/// republishes them as Observation-tracked properties so SwiftUI views that
/// read them re-render automatically.
///
/// One instance per `CEFWebView`. Access via `webView.observable` — that
/// accessor lazily creates and caches a single instance per webView.
///
/// ```swift
/// Text(tab.webView.observable.title ?? "new tab")  // updates live
/// ProgressView().opacity(tab.webView.observable.isLoading ? 1 : 0)
/// ```
@Observable
public final class CEFWebViewObservable {
    public let webView: CEFWebView

    public private(set) var title: String?
    public private(set) var url: URL?
    public private(set) var isLoading: Bool = false
    public private(set) var canGoBack: Bool = false
    public private(set) var canGoForward: Bool = false
    public private(set) var faviconImage: NSImage?

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    public init(_ webView: CEFWebView) {
        self.webView = webView
        // Seed initial values before observing — KVO with .initial would also
        // work but we prefer explicit reads here.
        self.title = webView.title
        self.url = webView.url
        self.isLoading = webView.isLoading
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward
        self.faviconImage = webView.faviconImage

        observations.append(webView.observe(\.title, options: [.new]) { [weak self] _, c in
            self?.title = c.newValue ?? nil
        })
        observations.append(webView.observe(\.url, options: [.new]) { [weak self] _, c in
            self?.url = c.newValue ?? nil
        })
        observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] _, c in
            self?.isLoading = c.newValue ?? false
        })
        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] _, c in
            self?.canGoBack = c.newValue ?? false
        })
        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] _, c in
            self?.canGoForward = c.newValue ?? false
        })
        observations.append(webView.observe(\.faviconImage, options: [.new]) { [weak self] _, c in
            self?.faviconImage = c.newValue ?? nil
        })
    }
}
