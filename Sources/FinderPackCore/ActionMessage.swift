import Foundation

public enum FileAction: String, Codable, Sendable { case copyPath, newFile, catalog, enableNotifications, openIn, moveTo, undoMove, cut, pasteFiles, pasteMove, moveHere }

public struct ActionRequest: Codable, Sendable, Equatable {
    public let version: Int
    public let created: Date
    public let id: UUID
    public let action: FileAction
    public let urls: [URL]
    public let target: URL?
    public let style: PathStyle?
    public let template: String?
    public let application: String?
    public let destination: URL?

    public init(id: UUID = UUID(), action: FileAction, urls: [URL] = [], target: URL? = nil,
                style: PathStyle? = nil, template: String? = nil, application: String? = nil, destination: URL? = nil) {
        version = 2
        self.id = id
        self.created = Date()
        self.action = action
        self.urls = urls
        self.target = target
        self.style = style
        self.template = template
        self.application = application
        self.destination = destination
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_048_576 else { throw MessageError.tooLarge }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.version == 2 else { throw MessageError.unsupportedVersion }
        guard abs(value.created.timeIntervalSinceNow) <= 300 else { throw MessageError.invalidContext }
        guard value.urls.count <= 10_000, value.urls.allSatisfy(validURL),
              (value.target.map(validURL) ?? true), (value.destination.map(validURL) ?? true) else { throw MessageError.invalidContext }
        switch value.action {
        case .copyPath:
            guard !value.urls.isEmpty, value.style != nil, value.template == nil else {
                throw MessageError.invalidContext
            }
        case .newFile:
            guard value.target != nil, let name = value.template, validName(name), value.style == nil else {
                throw MessageError.invalidContext
            }
        case .pasteFiles, .pasteMove, .moveHere:
            guard value.target != nil else { throw MessageError.invalidContext }
        case .moveTo, .cut:
            guard !value.urls.isEmpty else { throw MessageError.invalidContext }
        case .undoMove:
            guard value.urls.isEmpty else { throw MessageError.invalidContext }
        case .openIn:
            guard !value.urls.isEmpty, let application = value.application, application.utf8.count < 200 else {
                throw MessageError.invalidContext
            }
        case .catalog, .enableNotifications:
            guard value.urls.isEmpty, value.style == nil, value.template == nil else {
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
    public let recentDestinations: [URL]?
    public let gitRoot: URL?
    public let applications: [ApplicationChoice]?
    public let preferences: Preferences?
    public let templates: [String]

    public init(requestID: UUID, succeeded: Bool, message: String = "", templates: [String] = [], preferences: Preferences? = nil, gitRoot: URL? = nil, applications: [ApplicationChoice]? = nil, recentDestinations: [URL]? = nil) {
        version = 2
        self.requestID = requestID
        self.succeeded = succeeded
        self.message = message
        self.templates = templates
        self.preferences = preferences
        self.gitRoot = gitRoot
        self.applications = applications
        self.recentDestinations = recentDestinations
    }
}
