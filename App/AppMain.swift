import AppKit
import FinderSync
import ServiceManagement
import FinderPackCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let status = NSTextField(wrappingLabelWithString: "")
    private let result = NSTextField(wrappingLabelWithString: "No connection check has run.")
    private let client = DiagnosticClient()
    private let actions = ActionClient()
    private var service: SMAppService { .agent(plistName: "FinderPackAgent.plist") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FinderPack Prototype"
        let title = NSTextField(labelWithString: "Finder connection check")
        title.font = .preferredFont(forTextStyle: .title2)
        let note = NSTextField(wrappingLabelWithString: "Engineering prototype. This checks extension and agent setup. Copy Path and New File are available in Finder. Settings are still under development.")
        let stack = NSStackView(views: [title, note, status,
            button("Open Extension Settings", #selector(openExtensions)),
            button("Register Background Agent", #selector(registerAgent)),
            button("Open Background Settings", #selector(openBackgroundSettings)),
            button("Check Connection", #selector(checkConnection)),
            button("Enable Action Notifications", #selector(enableNotifications)),
            button("Unregister Background Agent", #selector(unregisterAgent)), result])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
            ])
        }
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStatus()
    }

    func applicationDidBecomeActive(_ notification: Notification) { refreshStatus() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }

    private func refreshStatus() {
        let agent: String
        switch service.status {
        case .enabled: agent = "enabled"
        case .notRegistered: agent = "not registered"
        case .requiresApproval: agent = "approval required"
        case .notFound: agent = "not found"
        @unknown default: agent = "unknown"
        }
        status.stringValue = "Extension: \(FIFinderSyncController.isExtensionEnabled ? "enabled" : "disabled"). Agent: \(agent)."
    }

    @objc private func openExtensions() { FIFinderSyncController.showExtensionManagementInterface() }
    @objc private func openBackgroundSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func registerAgent() {
        do {
            _ = try ServiceConfiguration()
            try service.register()
            result.stringValue = "Registration requested. Background approval may be required."
        } catch { result.stringValue = error.localizedDescription }
        refreshStatus()
    }
    @objc private func unregisterAgent() {
        do {
            try service.unregister()
            result.stringValue = "Agent unregistered."
        } catch { result.stringValue = error.localizedDescription }
        refreshStatus()
    }
    @objc private func enableNotifications() {
        actions.perform(ActionRequest(action: .enableNotifications)) { [weak self] reply in
            self?.result.stringValue = reply.message
        }
    }
    @objc private func checkConnection() {
        result.stringValue = "Checking connection..."
        client.ping { [weak self] message in self?.result.stringValue = message }
    }
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
