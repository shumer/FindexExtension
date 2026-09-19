import AppKit
import SwiftUI
import FinderPackCore

struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    let value: Shortcut?
    let changed: (Shortcut?) -> Void
    let action: String

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.target = button
        button.action = #selector(RecorderButton.record)
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.title = value?.display ?? label
        button.changed = changed
        button.shortcutAction = action
        button.existing = value
    }
}

final class RecorderButton: NSButton {
    var changed: ((Shortcut?) -> Void)?
    var shortcutAction = "copy"
    var existing: Shortcut?
    private var recording = false
    override var acceptsFirstResponder: Bool { true }
    @objc func record() {
        recording = true
        title = NSLocalizedString("Press shortcut (Esc cancels)", comment: "")
        window?.makeFirstResponder(self)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = existing?.display ?? NSLocalizedString("Record Shortcut", comment: ""); return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty else { NSSound.beep(); return }
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= 256 }
        if flags.contains(.shift) { carbon |= 512 }
        if flags.contains(.option) { carbon |= 2048 }
        if flags.contains(.control) { carbon |= 4096 }
        let display = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") +
            (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + (event.charactersIgnoringModifiers?.uppercased() ?? "")
        recording = false
        changed?(Shortcut(action: shortcutAction, keyCode: UInt32(event.keyCode), modifiers: carbon, display: display, global: existing?.global ?? false))
    }
}
