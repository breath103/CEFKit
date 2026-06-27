import AppKit
import ChromiumKit
import Foundation

let delegate = AppDelegate()

let config = ChromiumConfiguration(
    userAgent: "HelloChromium/0.3 (ChromiumKit; macOS)",
    cachePath: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloChromium")
)

exit(Int32(ChromiumApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeMenu()
    delegate.makeWindow()
}))
