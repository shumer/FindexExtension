import Foundation

public enum PathStyle: String, Codable, CaseIterable, Sendable {
    case posix, shellQuoted, fileURL, relative, gitRelative, homeRelative
    case name, stem, parent
}

public enum PathFormattingError: Error, Equatable {
    case nonFileURL, missingBase, outsideGitRoot
}

public enum PathFormatter {
    public static func format(
        _ url: URL, as style: PathStyle, directory: URL? = nil,
        gitRoot: URL? = nil, home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> String {
        guard url.isFileURL else { throw PathFormattingError.nonFileURL }
        let normalized = url.standardizedFileURL
        switch style {
        case .posix: return normalized.path
        case .shellQuoted: return shellQuote(normalized.path)
        case .fileURL: return normalized.absoluteString
        case .name: return normalized.lastPathComponent
        case .stem:
            let name = normalized.lastPathComponent
            if name.hasPrefix("."), !name.dropFirst().contains(".") { return name }
            return normalized.deletingPathExtension().lastPathComponent
        case .parent: return normalized.deletingLastPathComponent().path
        case .relative:
            guard let directory, directory.isFileURL else { throw PathFormattingError.missingBase }
            return relativePath(normalized, to: directory)
        case .gitRelative:
            guard let gitRoot, gitRoot.isFileURL else { throw PathFormattingError.missingBase }
            guard isWithin(normalized, directory: gitRoot) else {
                throw PathFormattingError.outsideGitRoot
            }
            return relativePath(normalized, to: gitRoot)
        case .homeRelative:
            guard home.isFileURL, isWithin(normalized, directory: home) else { return normalized.path }
            let suffix = relativePath(normalized, to: home)
            return suffix == "." ? "~" : "~/" + suffix
        }
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func isWithin(_ url: URL, directory: URL) -> Bool {
        url.standardizedFileURL.pathComponents.starts(with: directory.standardizedFileURL.pathComponents)
    }

    private static func relativePath(_ url: URL, to base: URL) -> String {
        let target = url.standardizedFileURL.pathComponents
        let origin = base.standardizedFileURL.pathComponents
        let common = zip(target, origin).prefix { $0 == $1 }.count
        let parts = Array(repeating: "..", count: origin.count - common) + Array(target.dropFirst(common))
        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }
}
