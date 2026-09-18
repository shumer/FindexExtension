import AppKit
import FinderSync
import OSLog
import os
import FinderPackCore

final class FinderSync: FIFinderSync {
    @MainActor private static let actionClient = ActionClient()
    @MainActor private static let catalogClient = ActionClient()
    private static let actions = OSAllocatedUnfairLock(initialState: (next: 1, values: [Int: String]()))
    private static let templates = OSAllocatedUnfairLock(initialState: [String]())
    @MainActor private static var refreshTask: Task<Void, Never>?

    @MainActor private static var volumeObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        Self.refreshDirectories()
        Task { @MainActor in
            Self.observeVolumes()
            Self.startCatalogRefresh()
        }
    }

    private static func refreshDirectories() {
        // Finder does not apply a root registration across mounted volume boundaries.
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        FIFinderSyncController.default().directoryURLs = Set(volumes + [URL(fileURLWithPath: "/")])
    }

    @MainActor private static func observeVolumes() {
        guard volumeObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        volumeObservers = [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: nil) { @Sendable _ in
                refreshDirectories()
            }
        }
        refreshDirectories()
    }

    @MainActor private static func startCatalogRefresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                catalogClient.perform(ActionRequest(action: .catalog)) { response in
                    templates.withLock { $0 = response.succeeded ? response.templates : [] }
                }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    override var toolbarItemName: String { "FinderPack" }
    override var toolbarItemToolTip: String { "FinderPack" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "FinderPack") ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let hasContext = controller.targetedURL() != nil || !(controller.selectedItemURLs() ?? []).isEmpty
        let menu = NSMenu(title: "FinderPack")
        menu.autoenablesItems = false
        let copy = NSMenuItem(title: ProductText.value("copy"), action: nil, keyEquivalent: "")
        let formats = NSMenu()
        formats.autoenablesItems = false
        for style in PathStyle.allCases where style != .gitRelative {
            formats.addItem(item(ProductText.value(style.rawValue), value: "copy:" + style.rawValue, enabled: hasContext))
        }
        copy.submenu = formats
        menu.addItem(copy)
        let names = Self.templates.withLock { $0 }
        if names.count == 1, let name = names.first {
            menu.addItem(item(ProductText.value("new") + ": " + name, value: "new:" + name, enabled: hasContext))
        } else {
            let create = NSMenuItem(title: ProductText.value("new"), action: nil, keyEquivalent: "")
            let choices = NSMenu()
            choices.autoenablesItems = false
            if names.isEmpty {
                choices.addItem(item(ProductText.value("loading"), value: "", enabled: false))
            } else {
                for name in names { choices.addItem(item(name, value: "new:" + name, enabled: hasContext)) }
            }
            create.submenu = choices
            menu.addItem(create)
        }
        return menu
    }

    private func item(_ title: String, value: String, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
        item.target = self
        item.tag = Self.actions.withLock { state in
            let tag = state.next
            state.next += 1
            state.values[tag] = value
            if state.values.count > 2_000 { state.values.removeValue(forKey: tag - 2_000) }
            return tag
        }
        item.isEnabled = enabled
        return item
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        Logger(subsystem: "com.shumer.finderpack.extension", category: "Actions").info("Menu action received with tag \(sender.tag).")
        let tag = sender.tag
        guard let value = Self.actions.withLock({ $0.values[tag] }) else { return }
        // Capture context on Finder's callback queue before dispatching asynchronous work.
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        let target = controller.targetedURL()
        let request: ActionRequest
        if value.hasPrefix("copy:"), let style = PathStyle(rawValue: String(value.dropFirst(5))) {
            request = ActionRequest(action: .copyPath, urls: selected.isEmpty ? target.map { [$0] } ?? [] : selected,
                                    target: target, style: style)
        } else if value.hasPrefix("new:") {
            request = ActionRequest(action: .newFile, target: target, template: String(value.dropFirst(4)))
        } else { return }
        Task { @MainActor in
            Self.actionClient.perform(request) { response in
                guard !response.succeeded else { return }
                let alert = NSAlert()
                alert.messageText = "FinderPack"
                alert.informativeText = response.message
                alert.addButton(withTitle: ProductText.value("ok"))
                alert.runModal()
            }
        }
    }
}
