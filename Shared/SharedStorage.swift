import Foundation
import FinderPackCore

enum SharedStorage {
    static func root() throws -> URL {
        let config = try ServiceConfiguration()
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.group) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return group.appendingPathComponent("Library/Application Support", isDirectory: true)
    }
    static func preferences() throws -> PreferencesStore {
        PreferencesStore(url: try root().appendingPathComponent("Preferences.json"))
    }
    static func templates() throws -> TemplateStore {
        TemplateStore(directory: try root().appendingPathComponent("Templates", isDirectory: true))
    }
}
