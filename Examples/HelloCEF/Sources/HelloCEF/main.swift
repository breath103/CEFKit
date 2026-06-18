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
