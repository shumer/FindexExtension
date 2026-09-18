import Foundation

public enum FileAction: String, Codable, Sendable { case copyPath, newFile, catalog, enableNotifications }

public struct ActionRequest: Codable, Sendable, Equatable {
    public let version: Int
    public let id: UUID
    public let action: FileAction
    public let urls: [URL]
    public let target: URL?
    public let style: PathStyle?
    public let template: String?

    public init(id: UUID = UUID(), action: FileAction, urls: [URL] = [], target: URL? = nil,
                style: PathStyle? = nil, template: String? = nil) {
        version = 1
        self.id = id
        self.action = action
        self.urls = urls
        self.target = target
        self.style = style
        self.template = template
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_048_576 else { throw MessageError.tooLarge }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.version == 1 else { throw MessageError.unsupportedVersion }
        guard value.urls.count <= 10_000, value.urls.allSatisfy(validURL),
              value.target.map(validURL) ?? true else { throw MessageError.invalidContext }
        switch value.action {
        case .copyPath:
            guard !value.urls.isEmpty, value.style != nil, value.template == nil else {
                throw MessageError.invalidContext
            }
        case .newFile:
            guard value.target != nil, let name = value.template, validName(name), value.style == nil else {
                throw MessageError.invalidContext
            }
        case .catalog, .enableNotifications:
            guard value.urls.isEmpty, value.target == nil, value.style == nil, value.template == nil else {
                throw MessageError.invalidContext
            }
        }
        return value
    }

    private static func validURL(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost") &&
            !url.path.utf8.contains(0) && url.path.hasPrefix("/")
    }

    public static func validName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") &&
            !name.utf8.contains(0) && name.utf8.count <= 200
    }
}

public struct ActionReply: Codable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let succeeded: Bool
    public let message: String
    public let templates: [String]

    public init(requestID: UUID, succeeded: Bool, message: String = "", templates: [String] = []) {
        version = 1
        self.requestID = requestID
        self.succeeded = succeeded
        self.message = message
        self.templates = templates
    }
}
