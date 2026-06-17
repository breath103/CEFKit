// HelloCEF — SwiftUI tabbed-browser shell built on CEFKit.
//
// Entry point only. The app is broken into:
//   BrowserTab.swift     model (tab + store)
//   FaviconView.swift    16×16 favicon or globe placeholder
//   TabRow.swift         sidebar list row
//   AddressBar.swift     back / forward / reload / URL
//   ContentView.swift    NavigationSplitView wiring; ZStack keeps all
//                        CEFWebViews mounted, toggling visibility
//   AppDelegate.swift    NSWindow + application menu

import AppKit
import CEFKit
import Foundation

let delegate = AppDelegate()

let config = CEFConfiguration(
    userAgent: "HelloCEF/0.3 (CEFKit; macOS)",
    cachePath: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloCEF")
)

exit(Int32(CEFApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeMenu()
    delegate.makeWindow()
}))
