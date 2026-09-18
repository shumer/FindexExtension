import Foundation

// A request-scoped marker proves both processes can use the same group container.
enum GroupProbe {
    static func marker(for id: UUID) throws -> URL {
        let config = try ServiceConfiguration()
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.group) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = container.appendingPathComponent("Library/Caches/Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(id.uuidString + ".txt")
    }

    static func prepare(_ id: UUID) throws {
        try Data("client:\(id.uuidString)".utf8).write(to: marker(for: id), options: .atomic)
    }

    static func respond(_ id: UUID) throws {
        let file = try marker(for: id)
        guard try Data(contentsOf: file) == Data("client:\(id.uuidString)".utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try Data("agent:\(id.uuidString)".utf8).write(to: file, options: .atomic)
    }

    static func verify(_ id: UUID) -> Bool {
        guard let file = try? marker(for: id), let data = try? Data(contentsOf: file) else { return false }
        return data == Data("agent:\(id.uuidString)".utf8)
    }

    static func clean(_ id: UUID) {
        guard let file = try? marker(for: id) else { return }
        try? FileManager.default.removeItem(at: file)
    }
}
