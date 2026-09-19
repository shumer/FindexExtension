import AppKit
import Combine
import FinderSync
import FinderPackCore
import ServiceManagement

@MainActor
final class SettingsModel: ObservableObject {
    @Published var preferences = Preferences()
    @Published var templates: [String] = []
    @Published var applications: [ApplicationChoice] = []
    @Published var moves: [MoveRecord] = []
    @Published var selected: String?
    @Published var content = ""
    @Published var editable = false
    @Published var message = ""
    @Published var extensionEnabled = false
    @Published var agentEnabled = false
    @Published var requestingNotifications = false
    @Published var failure: String?
    private var original: Data?
    private let client = ActionClient()
    private let notificationClient = ActionClient()
    private let diagnostic = DiagnosticClient()
    private var service: SMAppService { .agent(plistName: "FinderPackAgent.plist") }

    init() { reload() }

    func reload() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        agentEnabled = service.status == .enabled
        if agentEnabled {
            client.perform(ActionRequest(action: .catalog)) { [weak self] reply in
                if reply.succeeded { self?.applications = reply.applications ?? [] }
            }
        }
        do {
            preferences = try SharedStorage.preferences().load()
            let store = try SharedStorage.templates()
            try store.seed()
            templates = preferences.sorted(try store.catalog())
            let journal = try SharedStorage.root().appendingPathComponent("Moves")
            Task { [weak self] in
                do {
                    let records = try await Task.detached {
                        var groups = Set<UUID>()
                        return Array(try MoveEngine(journal: journal).records().filter {
                            $0.phase != "undone" && groups.insert($0.batch ?? $0.id).inserted
                        }.prefix(10))
                    }.value
                    self?.moves = records
                } catch { self?.failure = error.localizedDescription }
            }
        } catch { failure = error.localizedDescription }
    }

    func savePreferences() {
        do { try SharedStorage.preferences().save(preferences) }
        catch { failure = error.localizedDescription }
    }

    func select(_ name: String?) {
        if name != selected, let original, content != String(data: original, encoding: .utf8) {
            failure = NSLocalizedString("Save your changes or reload the current template before switching.", comment: "")
            return
        }
        selected = name
        original = nil
        content = ""
        editable = false
        guard let name else { return }
        do {
            let url = try templateURL(name, allowDirectory: true)
            if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                message = NSLocalizedString("Directory template. Use Reveal to edit its contents.", comment: "")
                return
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 1_048_576, let text = String(data: data, encoding: .utf8), !data.contains(0) else {
                message = NSLocalizedString("Binary template. Use Reveal to edit externally.", comment: "")
                return
            }
            original = data
            content = text
            editable = true
            message = ""
        } catch { failure = error.localizedDescription }
    }

    func saveTemplate() {
        guard let selected, let original else { return }
        do {
            let url = try templateURL(selected)
            guard try Data(contentsOf: url) == original else {
                failure = NSLocalizedString("The template changed outside this window. Reload before saving.", comment: "")
                return
            }
            let data = Data(content.utf8)
            guard data.count <= 1_048_576 else { throw MessageError.tooLarge }
            let mode = (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: mode & 0o777], ofItemAtPath: url.path)
            self.original = data
            message = NSLocalizedString("Saved", comment: "")
        } catch { failure = error.localizedDescription }
    }

    private func templateURL(_ name: String, allowDirectory: Bool = false) throws -> URL {
        guard ActionRequest.validName(name) else { throw TemplateError.invalidName }
        let url = try SharedStorage.templates().directory.appendingPathComponent(name)
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
        guard (attributes.isRegularFile == true || (allowDirectory && attributes.isDirectory == true)), attributes.isSymbolicLink != true,
              (attributes.fileSize ?? Int.max) <= 1_048_576 else { throw TemplateError.unsupportedTemplate }
        return url
    }

    func addTemplate() {
        let panel = NSSavePanel()
        panel.directoryURL = try? SharedStorage.templates().directory
        panel.nameFieldStringValue = "Untitled.txt"
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        do {
            let root = try SharedStorage.templates().directory.standardizedFileURL
            guard chosen.deletingLastPathComponent().standardizedFileURL == root,
                  ActionRequest.validName(chosen.lastPathComponent) else { throw TemplateError.invalidName }
            try Data().write(to: chosen, options: .withoutOverwriting)
            reload()
            select(chosen.lastPathComponent)
        } catch { failure = error.localizedDescription }
    }

    func importTemplates() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK else { return }
        importURLs(panel.urls)
    }

    func importURLs(_ urls: [URL]) {
        do {
            let store = try SharedStorage.templates()
            for url in urls {
                let source = TemplateStore(directory: url.deletingLastPathComponent())
                _ = try source.create(template: url.lastPathComponent, in: store.directory, expandPlaceholders: false)
            }
            reload()
        } catch { failure = error.localizedDescription; reload() }
    }

    func removeTemplate() {
        guard let selected else { return }
        do {
            try FileManager.default.trashItem(at: templateURL(selected, allowDirectory: true), resultingItemURL: nil)
            original = nil
            select(nil)
            reload()
        } catch { failure = error.localizedDescription }
    }

    func revealTemplates() {
        do {
            let root = try SharedStorage.templates().directory
            NSWorkspace.shared.activateFileViewerSelecting([selected.map { root.appendingPathComponent($0) } ?? root])
        } catch { failure = error.localizedDescription }
    }

    func reorder(_ offset: Int) {
        guard let selected, let index = templates.firstIndex(of: selected), templates.indices.contains(index + offset) else { return }
        templates.swapAt(index, index + offset)
        for (order, name) in templates.enumerated() {
            var metadata = preferences.templates[name] ?? TemplateMetadata()
            metadata.order = order
            preferences.templates[name] = metadata
        }
        savePreferences()
    }

    func undoMove(_ record: MoveRecord) {
        client.perform(ActionRequest(action: .undoMove, template: record.id.uuidString)) { [weak self] reply in
            if !reply.succeeded { self?.failure = reply.message }
            self?.reload()
        }
    }
    func revealMove(_ record: MoveRecord) {
        let records = (try? MoveEngine(journal: SharedStorage.root().appendingPathComponent("Moves")).records()) ?? [record]
        let group = records.filter { ($0.batch ?? $0.id) == (record.batch ?? record.id) }
        let locations = group.flatMap { [$0.source, $0.destination, $0.retained, $0.staging] }.filter { FileManager.default.fileExists(atPath: $0.path) }
        NSWorkspace.shared.activateFileViewerSelecting(Array(Set(locations)))
    }

    func openExtensions() { FIFinderSyncController.showExtensionManagementInterface() }
    func openBackgroundSettings() { SMAppService.openSystemSettingsLoginItems() }
    func register() {
        do { try service.register(); reload() } catch { failure = error.localizedDescription }
    }
    func unregister() {
        do { try service.unregister(); reload() } catch { failure = error.localizedDescription }
    }
    func checkConnection() { diagnostic.ping { [weak self] in self?.message = $0 } }
    func enableNotifications() {
        guard !requestingNotifications else { return }
        requestingNotifications = true
        message = ProductText.value("notificationWaiting")
        notificationClient.perform(ActionRequest(action: .enableNotifications)) { [weak self] reply in
            self?.requestingNotifications = false
            self?.message = reply.message
        }
    }
}
