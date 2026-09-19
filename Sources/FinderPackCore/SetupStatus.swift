import Foundation

public enum PermissionState: String, Codable, Sendable {
    case allowed, notRequested, denied, unknown
}

public struct SetupStatus: Codable, Sendable, Equatable {
    public let accessibility: Bool
    public let finderAutomation: PermissionState
    public let notifications: PermissionState

    public init(accessibility: Bool, finderAutomation: PermissionState, notifications: PermissionState) {
        self.accessibility = accessibility
        self.finderAutomation = finderAutomation
        self.notifications = notifications
    }
}
