import Foundation

public struct TemplateMetadata: Codable, Sendable, Equatable {
    public var label: String
    public var symbol: String
    public var order: Int
    public init(label: String = "", symbol: String = "doc", order: Int = 0) {
        self.label = label
        self.symbol = symbol
        self.order = order
    }
}

public enum PathSeparator: String, Codable, CaseIterable, Sendable {
    case newline, space, comma
    public var text: String {
        switch self { case .newline: return "\n"; case .space: return " "; case .comma: return ", " }
    }
}

public struct Shortcut: Codable, Sendable, Equatable {
    public let action: String
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let display: String
    public var global: Bool
    public init(action: String, keyCode: UInt32, modifiers: UInt32, display: String, global: Bool = false) {
        self.action = action; self.keyCode = keyCode; self.modifiers = modifiers; self.display = display; self.global = global
    }
}

public struct Preferences: Codable, Sendable, Equatable {
    public var version = 1
    public var preferredApplication = "com.apple.Terminal"
    public var disabledApplications: [String] = []
    public var groupOrder = ["copy", "new", "open", "move"]
    public var showCopy = true
    public var showNew = true
    public var showOpen = true
    public var showMove = true
    public var defaultPath = PathStyle.posix
    public var separator = PathSeparator.newline
    public var notifySuccess = true
    public var author = ""
    public var shortcuts: [Shortcut] = []
    public var templates: [String: TemplateMetadata] = [:]
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case preferredApplication, disabledApplications, groupOrder
        case version, showCopy, showNew, showOpen, showMove, defaultPath, separator, notifySuccess, author, templates, shortcuts
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        preferredApplication = try values.decodeIfPresent(String.self, forKey: .preferredApplication) ?? "com.apple.Terminal"
        disabledApplications = try values.decodeIfPresent([String].self, forKey: .disabledApplications) ?? []
        groupOrder = try values.decodeIfPresent([String].self, forKey: .groupOrder) ?? ["copy", "new", "open", "move"]
        version = try values.decode(Int.self, forKey: .version)
        showCopy = try values.decodeIfPresent(Bool.self, forKey: .showCopy) ?? true
        showNew = try values.decodeIfPresent(Bool.self, forKey: .showNew) ?? true
        showOpen = try values.decodeIfPresent(Bool.self, forKey: .showOpen) ?? true
        showMove = try values.decodeIfPresent(Bool.self, forKey: .showMove) ?? true
        defaultPath = try values.decodeIfPresent(PathStyle.self, forKey: .defaultPath) ?? .posix
        separator = try values.decodeIfPresent(PathSeparator.self, forKey: .separator) ?? .newline
        notifySuccess = try values.decodeIfPresent(Bool.self, forKey: .notifySuccess) ?? true
        author = try values.decodeIfPresent(String.self, forKey: .author) ?? ""
        templates = try values.decodeIfPresent([String: TemplateMetadata].self, forKey: .templates) ?? [:]
        shortcuts = try values.decodeIfPresent([Shortcut].self, forKey: .shortcuts) ?? []
    }

    public func validate() throws {
        guard Set(groupOrder) == Set(["copy", "new", "open", "move"]), groupOrder.count == 4,
              preferredApplication.utf8.count < 200, disabledApplications.count <= 50,
              disabledApplications.allSatisfy({ $0.utf8.count < 200 }),
              Set(shortcuts.map { "\($0.keyCode):\($0.modifiers)" }).count == shortcuts.count,
              shortcuts.count <= 2, Set(shortcuts.map(\.action)).count == shortcuts.count,
              shortcuts.allSatisfy({ ["copy", "new"].contains($0.action) && $0.display.utf8.count <= 64 && $0.keyCode < 128 && $0.modifiers & 6400 != 0 }),
              version == 1, author.utf8.count <= 1024, templates.count <= 1000,
              templates.allSatisfy({ ActionRequest.validName($0.key) && $0.value.label.utf8.count <= 200 &&
                  ["doc", "doc.text", "chevron.left.forwardslash.chevron.right", "terminal", "note.text"].contains($0.value.symbol) }) else {
            throw MessageError.invalidContext
        }
    }

    public func sorted(_ names: [String]) -> [String] {
        names.sorted {
            let left = templates[$0]?.order ?? 0, right = templates[$1]?.order ?? 0
            return left == right ? $0.localizedStandardCompare($1) == .orderedAscending : left < right
        }
    }

    public func label(for name: String) -> String {
        if let label = templates[name]?.label, !label.isEmpty { return label }
        if name.hasPrefix(".") { return name }
        return (name as NSString).deletingPathExtension
    }
}

public struct PreferencesStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Preferences {
        guard FileManager.default.fileExists(atPath: url.path) else { return Preferences() }
        let data = try Data(contentsOf: url)
        guard data.count <= 1_048_576 else { throw MessageError.tooLarge }
        let result = try JSONDecoder().decode(Preferences.self, from: data)
        try result.validate()
        return result
    }
    public func save(_ value: Preferences) throws {
        try value.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
