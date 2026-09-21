import AppKit
import FinderSync
import OSLog
import os
import FinderPackCore

final class FinderSync: FIFinderSync {
    @MainActor private static let actionClient = ActionClient()
    @MainActor private static let catalogClient = ActionClient()
    private static let actions = OSAllocatedUnfairLock(initialState: (next: 1, values: [Int: String]()))
    private static let context = OSAllocatedUnfairLock(initialState: (target: Optional<URL>.none, gitTarget: Optional<URL>.none))
    private static let canToggleHiddenFiles = OSAllocatedUnfairLock(initialState: false)
    private static let recents = OSAllocatedUnfairLock(initialState: [URL]())
    private static let applications = OSAllocatedUnfairLock(initialState: [ApplicationChoice]())
    private static let templates = OSAllocatedUnfairLock(initialState: (names: [String](), preferences: Preferences()))
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
                let target = context.withLock { $0.target }
                catalogClient.perform(ActionRequest(action: .catalog, target: target)) { response in
                    guard response.succeeded else {
                        canToggleHiddenFiles.withLock { $0 = false }
                        return
                    }
                    canToggleHiddenFiles.withLock { $0 = response.canToggleHiddenFiles == true }
                    context.withLock { $0.gitTarget = response.gitRoot == nil ? nil : target }
                    applications.withLock { $0 = response.applications ?? [] }
                    recents.withLock { $0 = response.recentDestinations ?? [] }
                    templates.withLock { $0 = (response.succeeded ? response.templates : [], response.preferences ?? Preferences()) }
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
        let target = controller.targetedURL()
        Self.context.withLock { $0.target = target }
        let hasGit = target != nil && Self.context.withLock { $0.gitTarget == target }
        let hasContext = controller.targetedURL() != nil || !(controller.selectedItemURLs() ?? []).isEmpty
        let menu = NSMenu(title: "FinderPack")
        menu.autoenablesItems = false
        let snapshot = Self.templates.withLock { $0 }
        let preferences = snapshot.preferences
        defer {
            let ordered = menu.items.sorted { left, right in
                (preferences.groupOrder.firstIndex(of: left.identifier?.rawValue ?? "") ?? 100) <
                    (preferences.groupOrder.firstIndex(of: right.identifier?.rawValue ?? "") ?? 100)
            }
            menu.removeAllItems()
            for entry in ordered { menu.addItem(entry) }
        }
        let copy = NSMenuItem(title: ProductText.value("copy"), action: nil, keyEquivalent: "")
        let formats = NSMenu()
        formats.autoenablesItems = false
        let orderedStyles = preferences.visiblePathStyles
        for style in orderedStyles where style != .gitRelative || hasGit {
            formats.addItem(item(ProductText.value(style.rawValue), value: "copy:" + style.rawValue, enabled: hasContext))
        }
        copy.identifier = NSUserInterfaceItemIdentifier("copy")
        copy.submenu = formats
        if preferences.showCopy && !formats.items.isEmpty { menu.addItem(copy) }
        if preferences.showOpen {
            let open = NSMenuItem(title: ProductText.value("open"), action: nil, keyEquivalent: "")
            let choices = NSMenu()
            choices.autoenablesItems = false
            open.identifier = NSUserInterfaceItemIdentifier("open")
            let applications = Self.applications.withLock { $0 }.filter { !preferences.disabledApplications.contains($0.identifier) }.sorted {
                if $0.identifier == $1.identifier { return false }
                if $0.identifier == preferences.preferredApplication { return true }
                if $1.identifier == preferences.preferredApplication { return false }
                return $0.name < $1.name
            }
            for application in applications {
                choices.addItem(item(application.name, value: "open:" + application.identifier, enabled: hasContext))
            }
            if !choices.items.isEmpty { open.submenu = choices; menu.addItem(open) }
        }
        if preferences.showMove {
            let move = NSMenuItem(title: ProductText.value("move"), action: nil, keyEquivalent: "")
            let choices = NSMenu()
            choices.autoenablesItems = false
            let hasSelection = !(controller.selectedItemURLs() ?? []).isEmpty
            let commands: [(MenuCommand, String, Bool)] = [
                (.chooseDestination, "move:", hasSelection), (.cut, "cut:", hasSelection),
                (.pasteFiles, "paste:", target != nil), (.pasteMove, "pasteMove:", target != nil),
                (.moveHere, "moveHere:", target != nil)
            ]
            for (command, value, enabled) in commands where preferences.shows(command) {
                choices.addItem(item(ProductText.value(command.rawValue), value: value, enabled: enabled))
            }
            let destinations = preferences.menuDestinations(recent: Self.recents.withLock { $0 })
            for favorite in [true, false] {
                let group = destinations.filter { $0.favorite == favorite }
                guard !group.isEmpty else { continue }
                if !choices.items.isEmpty { choices.addItem(.separator()) }
                let heading = NSMenuItem(title: ProductText.value(favorite ? "favoriteDestinations" : "recentDestinations"), action: nil, keyEquivalent: "")
                heading.isEnabled = false
                choices.addItem(heading)
                for destination in group {
                    let entry = item(destination.title, value: "moveTo:" + destination.url.absoluteString, enabled: hasSelection)
                    entry.toolTip = destination.url.path
                    if favorite { entry.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil) }
                    choices.addItem(entry)
                }
            }
            if preferences.shows(.undoMove) {
                if !destinations.isEmpty { choices.addItem(.separator()) }
                choices.addItem(item(ProductText.value("undoMove"), value: "undo:", enabled: true))
            }
            move.identifier = NSUserInterfaceItemIdentifier("move")
            move.submenu = choices
            if !choices.items.isEmpty { menu.addItem(move) }
        }
        if preferences.shows(.hiddenFiles) {
            let hidden = item(ProductText.value("hiddenFiles"), value: "hidden:toggle", enabled: Self.canToggleHiddenFiles.withLock { $0 })
            hidden.identifier = NSUserInterfaceItemIdentifier("hiddenFiles")
            menu.addItem(hidden)
        }
        guard preferences.showNew else { return menu }
        let names = snapshot.names.filter { !preferences.disabledTemplates.contains($0) }
        if names.isEmpty && !snapshot.names.isEmpty { return menu }
        if names.count == 1, let name = names.first {
            let entry = item(ProductText.value("new") + ": " + preferences.label(for: name), value: "new:" + name, enabled: target != nil)
            entry.image = NSImage(systemSymbolName: preferences.templates[name]?.symbol ?? "doc", accessibilityDescription: nil)
            entry.identifier = NSUserInterfaceItemIdentifier("new")
            menu.addItem(entry)
        } else {
            let create = NSMenuItem(title: ProductText.value("new"), action: nil, keyEquivalent: "")
            let choices = NSMenu()
            choices.autoenablesItems = false
            if names.isEmpty {
                choices.addItem(item(ProductText.value("loading"), value: "", enabled: false))
            } else {
                for name in names {
                    let metadata = preferences.templates[name]
                    let label = preferences.label(for: name)
                    let entry = item(label, value: "new:" + name, enabled: target != nil)
                    entry.image = NSImage(systemSymbolName: metadata?.symbol ?? "doc", accessibilityDescription: nil)
                    choices.addItem(entry)
                }
            }
            create.identifier = NSUserInterfaceItemIdentifier("new")
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
            let base = target.map { url in
                selected.contains(where: { $0.path == url.path }) ? url.deletingLastPathComponent() : url
            }
            request = ActionRequest(action: .copyPath, urls: selected.isEmpty ? target.map { [$0] } ?? [] : selected,
                                    target: style == .relative ? base : target, style: style)
        } else if value.hasPrefix("open:") {
            request = ActionRequest(action: .openIn, urls: selected.isEmpty ? target.map { [$0] } ?? [] : selected,
                                    application: String(value.dropFirst(5)))
        } else if value.hasPrefix("moveTo:"), let destination = URL(string: String(value.dropFirst(7))) {
            request = ActionRequest(action: .moveTo, urls: selected, destination: destination)
        } else if value == "moveHere:" {
            request = ActionRequest(action: .moveHere, target: target)
        } else if value == "cut:" {
            request = ActionRequest(action: .cut, urls: selected)
        } else if value == "paste:" || value == "pasteMove:" {
            request = ActionRequest(action: value == "paste:" ? .pasteFiles : .pasteMove, target: target)
        } else if value == "move:" {
            request = ActionRequest(action: .moveTo, urls: selected)
        } else if value == "undo:" {
            request = ActionRequest(action: .undoMove)
        } else if value == "hidden:toggle" {
            request = ActionRequest(action: .toggleHiddenFiles)
        } else if value.hasPrefix("new:") {
            request = ActionRequest(action: .newFile, target: target, template: String(value.dropFirst(4)))
        } else { return }
        Task { @MainActor in
            Self.actionClient.perform(request) { response in
                guard !response.succeeded else { return }
                ActionErrorPresenter.shared.show(response.message)
            }
        }
    }
}
