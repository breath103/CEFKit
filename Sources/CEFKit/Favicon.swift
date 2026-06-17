@_exported import CEFViewObjC
import AppKit
import Foundation
import Observation

/// One favicon for one URL. `url` is fixed at construction; `image` lands
/// asynchronously when CEF's image loader finishes (nil while pending, or
/// if the download failed).
///
/// CEFView creates a fresh `Favicon` for each new favicon URL the page
/// reports, so a late download callback writing to a stale instance is
/// silently ignored — no race guard needed.
@Observable
public final class Favicon {
    public let url: URL
    public private(set) var image: NSImage?

    @ObservationIgnored private var imageObs: NSKeyValueObservation?

    init(_ ref: CEFFaviconRef) {
        self.url = ref.url
        self.image = ref.image
        self.imageObs = ref.observe(\.image, options: [.new]) { [weak self] _, c in
            self?.image = c.newValue ?? nil
        }
    }
}
