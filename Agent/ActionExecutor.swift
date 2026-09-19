import AppKit
import Foundation
import FinderPackCore
import UserNotifications
import OSLog

actor ActionExecutor {
    static let shared = ActionExecutor()
    private var lastReceiptCleanup = Date.distantPast

    func perform(_ request: ActionRequest) async -> ActionReply {
        do {
            if request.action == .setupStatus {
                return ActionReply(requestID: request.id, succeeded: true, setupStatus: await PermissionStatus.snapshot())
            }
            if request.action == .requestAccessibility {
                await PermissionStatus.requestAccessibility()
                return ActionReply(requestID: request.id, succeeded: true, setupStatus: await PermissionStatus.snapshot())
            }
            if request.action == .requestFinderAutomation {
                _ = await Task.detached { PermissionStatus.finderAutomation(prompt: true) }.value
                return ActionReply(requestID: request.id, succeeded: true, setupStatus: await PermissionStatus.snapshot())
            }
            let root = try SharedStorage.root()
            let preferences = try SharedStorage.preferences().load()
            let store = TemplateStore(directory: root.appendingPathComponent("Templates", isDirectory: true))
            if request.action == .catalog {
                try store.seed()
                return ActionReply(requestID: request.id, succeeded: true, templates: Array(preferences.sorted(try store.catalog()).prefix(100)), preferences: preferences, gitRoot: request.target.flatMap(GitDiscovery.root), applications: await ApplicationActions.installed(), recentDestinations: MoveActions.recent(), canToggleHiddenFiles: true)
            }
            if request.action == .enableNotifications {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                return ActionReply(requestID: request.id, succeeded: allowed,
                                   message: NSLocalizedString(allowed ? "Notifications enabled." : "Allow notifications in System Settings if you want success messages.", comment: ""))
            }
            let journal = root.appendingPathComponent("ActionRequests", isDirectory: true)
            try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true)
            if Date().timeIntervalSince(lastReceiptCleanup) > 3600 {
                let files = try FileManager.default.contentsOfDirectory(at: journal, includingPropertiesForKeys: [.contentModificationDateKey])
                for file in files where file.pathExtension == "json" {
                    if let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       Date().timeIntervalSince(modified) > 172800 { try FileManager.default.removeItem(at: file) }
                }
                lastReceiptCleanup = Date()
            }
            let receipt = journal.appendingPathComponent(request.id.uuidString + ".json")
            // Reserve the request before side effects; interrupted requests are never replayed automatically.
            do { try JSONEncoder().encode(request).write(to: receipt, options: .withoutOverwriting) }
            catch CocoaError.fileWriteFileExists {
                return ActionReply(requestID: request.id, succeeded: false, message: ProductText.value("uncertain"))
            }
            switch request.action {
            case .toggleHiddenFiles:
                try await FinderVisibility.toggle()
                return ActionReply(requestID: request.id, succeeded: true)
            case .copyPath:
                guard let style = request.style else { throw MessageError.invalidContext }
                let directory = style == .relative ? try request.target.map { try destination($0) } : nil
                let text = try request.urls.map { try PathFormatter.format($0, as: style, directory: directory, gitRoot: style == .gitRelative ? GitDiscovery.root(containing: $0) : nil) }.joined(separator: preferences.separator.text)
                let written = await MainActor.run {
                    NSPasteboard.general.clearContents()
                    return NSPasteboard.general.setString(text, forType: .string)
                }
                guard written else { throw CocoaError(.fileWriteUnknown) }
                await notify("copied")
            case .newFile:
                guard let target = request.target, let template = request.template else { throw MessageError.invalidContext }
                let folder = try destination(target)
                let created = try store.create(template: template, in: folder, id: request.id, author: preferences.author.isEmpty ? NSFullUserName() : preferences.author)
                await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([created]) }
                await notify("created")
            case .cut:
                try await FileClipboard.cut(request.urls)
            case .pasteFiles, .pasteMove, .moveHere:
                guard let target = request.target else { throw MessageError.invalidContext }
                let folder = try destination(target)
                let urls = try await FileClipboard.read(moving: request.action == .pasteMove)
                try await MoveActions.shared.move(urls, destination: folder, copying: request.action == .pasteFiles)
            case .moveTo:
                try await MoveActions.shared.move(request.urls, destination: request.destination)
            case .undoMove:
                try await MoveActions.shared.undo(id: request.template)
            case .openIn:
                guard let application = request.application else { throw MessageError.invalidContext }
                try await ApplicationActions.open(application, urls: request.urls)
            case .catalog, .enableNotifications, .setupStatus, .requestFinderAutomation, .requestAccessibility: break
            }
            return ActionReply(requestID: request.id, succeeded: true)
        } catch {
            Logger(subsystem: "com.shumer.finderpack.agent", category: "Actions").error("File action failed: \(String(describing: error), privacy: .private)")
            if error is MoveError || [FileAction.moveTo, .undoMove, .pasteFiles, .pasteMove, .moveHere].contains(request.action) {
                return ActionReply(requestID: request.id, succeeded: false, message: NSLocalizedString("Move stopped. Some files may already have moved. Existing data was kept. Check the destination and the move journal before retrying.", comment: ""))
            }
            if request.action == .toggleHiddenFiles {
                return ActionReply(requestID: request.id, succeeded: false, message: error.localizedDescription)
            }
            if request.action == .openIn {
                return ActionReply(requestID: request.id, succeeded: false, message: error.localizedDescription)
            }
            let partial = (error as? TemplateError) == .writeFailed
            return ActionReply(requestID: request.id, succeeded: false, message: ProductText.value(partial ? "partial" : "failed"))
        }
    }

    private func destination(_ target: URL) throws -> URL {
        let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
        guard values.isSymbolicLink != true, values.isPackage != true else { throw MessageError.invalidContext }
        return values.isDirectory == true ? target : target.deletingLastPathComponent()
    }

    private func notify(_ key: String) async {
        guard (try? SharedStorage.preferences().load().notifySuccess) == true else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "FinderPack"
        content.body = ProductText.value(key)
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
