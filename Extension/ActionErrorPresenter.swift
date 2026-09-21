import AppKit

@MainActor
final class ActionErrorPresenter: NSObject {
    static let shared = ActionErrorPresenter()
    private var alert: NSAlert?

    func show(_ message: String) {
        dismiss()
        let alert = NSAlert()
        alert.messageText = "FinderPack"
        alert.informativeText = message
        let button = alert.addButton(withTitle: ProductText.value("ok"))
        alert.layout()
        let window = alert.window
        button.target = self
        button.action = #selector(dismiss)
        self.alert = alert
        // A modal loop inside the action task blocks subsequent Finder menu requests.
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func dismiss() {
        alert?.window.close()
        alert = nil
    }
}
