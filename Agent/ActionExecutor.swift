import AppKit
import Foundation
import FinderPackCore
import UserNotifications
import OSLog

actor ActionExecutor {
    static let shared = ActionExecutor()

    private func storage() throws -> URL {
        let config = try ServiceConfiguration()
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.group) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return group.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    func perform(_ request: ActionRequest) async -> ActionReply {
        do {
            let root = try storage()
            let store = TemplateStore(directory: root.appendingPathComponent("Templates", isDirectory: true))
            if request.action == .catalog {
                try store.seed()
                return ActionReply(requestID: request.id, succeeded: true, templates: Array(try store.catalog().prefix(100)))
            }
            if request.action == .enableNotifications {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                return ActionReply(requestID: request.id, succeeded: allowed,
                                   message: allowed ? "Notifications enabled." : "Allow notifications in System Settings if you want success messages.")
            }
            let journal = root.appendingPathComponent("ActionRequests", isDirectory: true)
            try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true)
            let receipt = journal.appendingPathComponent(request.id.uuidString + ".json")
            // Reserve the request before side effects; interrupted requests are never replayed automatically.
            do { try JSONEncoder().encode(request).write(to: receipt, options: .withoutOverwriting) }
            catch CocoaError.fileWriteFileExists {
                return ActionReply(requestID: request.id, succeeded: false, message: ProductText.value("uncertain"))
            }
            switch request.action {
            case .copyPath:
                guard let style = request.style else { throw MessageError.invalidContext }
                let directory = style == .relative ? try request.target.map { try destination($0) } : nil
                let text = try request.urls.map { try PathFormatter.format($0, as: style, directory: directory) }.joined(separator: "\n")
                let written = await MainActor.run {
                    NSPasteboard.general.clearContents()
                    return NSPasteboard.general.setString(text, forType: .string)
                }
                guard written else { throw CocoaError(.fileWriteUnknown) }
                await notify("copied")
            case .newFile:
                guard let target = request.target, let template = request.template else { throw MessageError.invalidContext }
                let folder = try destination(target)
                let created = try store.create(template: template, in: folder, id: request.id)
                await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([created]) }
                await notify("created")
            case .catalog, .enableNotifications: break
            }
            return ActionReply(requestID: request.id, succeeded: true)
        } catch {
            Logger(subsystem: "com.shumer.finderpack.agent", category: "Actions").error("File action failed: \(String(describing: error), privacy: .private)")
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
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "FinderPack"
        content.body = ProductText.value(key)
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
