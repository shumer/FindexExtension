import AppKit
import Carbon
import FinderPackCore

@MainActor
final class ShortcutService {
    static let shared = ShortcutService()
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var active: [Shortcut] = []
    private var poll: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    func start() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotkey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotkey)
            guard status == noErr else { return status }
            let id = hotkey.id
            Task { @MainActor in ShortcutService.shared.invoke(Int(id)) }
            return noErr
        }, 1, &event, nil, &handler)
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { @Sendable _ in
            Task { @MainActor in ShortcutService.shared.refresh() }
        }
        poll = Task {
            while !Task.isCancelled {
                refresh()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    private func refresh() {
        guard let preferences = try? SharedStorage.preferences().load() else { return }
        let finderFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        let desired = preferences.shortcuts.filter { $0.global || finderFrontmost }
        guard desired != active else { return }
        for reference in references { UnregisterEventHotKey(reference) }
        references = []
        active = desired
        for (index, shortcut) in active.enumerated() {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x46504B54, id: UInt32(index)), GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { references.append(reference) }
            else {
                let alert = NSAlert()
                alert.messageText = "FinderPack"
                alert.informativeText = NSLocalizedString("A shortcut is already in use. Choose another combination in Settings.", comment: "")
                alert.runModal()
            }
        }
    }

    private func invoke(_ index: Int) {
        guard active.indices.contains(index) else { return }
        let shortcut = active[index]
        // This script contains no user-supplied source; paths are returned as data.
        let source = """
        tell application "Finder"
            set chosenPaths to {}
            repeat with chosen in selection
                set end of chosenPaths to POSIX path of (chosen as alias)
            end repeat
            if (count of windows) is 0 then error "Open a Finder window first."
            set folderPath to POSIX path of (target of front window as alias)
            return {folderPath, chosenPaths}
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return }
        let result = script.executeAndReturnError(&error)
        guard error == nil, let targetPath = result.atIndex(1)?.stringValue else {
            let alert = NSAlert()
            alert.messageText = "FinderPack"
            alert.informativeText = NSLocalizedString("Open a Finder window and allow Automation for FinderPack in System Settings to use shortcuts.", comment: "")
            alert.runModal()
            return
        }
        let target = URL(fileURLWithPath: targetPath)
        let list = result.atIndex(2)
        let count = list?.numberOfItems ?? 0
        let selected = count > 0 ? (1...count).compactMap { list?.atIndex($0)?.stringValue }.map { URL(fileURLWithPath: $0) } : []
        let request: ActionRequest
        switch shortcut.action {
        case "copy": request = ActionRequest(action: .copyPath, urls: selected.isEmpty ? [target] : selected, target: target,
                                             style: (try? SharedStorage.preferences().load().defaultPath) ?? .posix)
        case "new":
            guard let templates = try? SharedStorage.templates().catalog(), let name = ((try? SharedStorage.preferences().load()) ?? Preferences()).sorted(templates).first else { return }
            request = ActionRequest(action: .newFile, target: target, template: name)
        default: return
        }
        Task {
            let reply = await ActionExecutor.shared.perform(request)
            if !reply.succeeded {
                let alert = NSAlert()
                alert.messageText = "FinderPack"
                alert.informativeText = reply.message
                alert.runModal()
            }
        }
    }
}
