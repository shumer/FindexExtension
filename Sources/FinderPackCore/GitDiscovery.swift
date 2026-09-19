import Foundation

public enum GitDiscovery {
    public static func root(containing url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        var current = isDirectory.boolValue ? url.standardizedFileURL : url.deletingLastPathComponent().standardizedFileURL
        for _ in 0..<256 {
            let marker = current.appendingPathComponent(".git")
            if let values = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]),
               values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
        }
        return nil
    }
}

public struct ApplicationChoice: Codable, Sendable, Equatable {
    public let identifier: String
    public let name: String
    public init(identifier: String, name: String) { self.identifier = identifier; self.name = name }
}
