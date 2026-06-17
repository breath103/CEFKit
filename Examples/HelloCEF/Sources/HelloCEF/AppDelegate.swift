import AppKit
import Foundation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TabStore()
    var window: NSWindow!

    func makeMenu() {
        // Minimal application menu — without this Cmd+Q is dead.
        // CEFApplication's NSApplication subclass overrides `terminate:`
        // to call CefQuitMessageLoop(), so the standard Quit item unwinds
        // CEF cleanly.
        let appName = ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    func makeWindow() {
        store.newTab(URL(string: "https://news.ycombinator.com")!)
        store.newTab(URL(string: "https://example.com")!)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "HelloCEF"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView(store: store))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
