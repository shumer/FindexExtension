import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateController.shared.restoreHelper()
        UpdateController.shared.start()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FinderPack"
        window.contentView = NSHostingView(rootView: SettingsView())
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let menu = NSMenu()
        let application = NSMenuItem()
        let commands = NSMenu()
        commands.addItem(withTitle: NSLocalizedString("Quit FinderPack", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = commands
        menu.addItem(application)
        let edit = NSMenuItem(title: NSLocalizedString("Edit", comment: ""), action: nil, keyEquivalent: "")
        let edits = NSMenu(title: edit.title)
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edits.addItem(withTitle: NSLocalizedString(title, comment: ""), action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        edit.submenu = edits
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AppMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
