import Foundation

public enum MessageError: Error, Equatable {
    case tooLarge, unsupportedVersion, invalidContext
}

public struct DiagnosticRequest: Codable, Sendable, Equatable {
    public let version: Int
    public let id: UUID
    public let selectedURLs: [URL]
    public let targetedURL: URL?

    public init(id: UUID = UUID(), selectedURLs: [URL] = [], targetedURL: URL? = nil) {
        self.version = 1
        self.id = id
        self.selectedURLs = selectedURLs
        self.targetedURL = targetedURL
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_048_576 else { throw MessageError.tooLarge }
        let request = try JSONDecoder().decode(Self.self, from: data)
        guard request.version == 1 else { throw MessageError.unsupportedVersion }
        guard request.selectedURLs.count <= 10_000,
              request.selectedURLs.allSatisfy({ $0.isFileURL }),
              request.targetedURL.map({ $0.isFileURL }) ?? true else {
            throw MessageError.invalidContext
        }
        return request
    }
}

public struct DiagnosticReply: Codable, Sendable {
    public let requestID: UUID
    public let version: Int
    public let accepted: Bool

    public init(requestID: UUID, accepted: Bool) {
        self.requestID = requestID
        self.version = 1
        self.accepted = accepted
    }
}
