import AppKit
import Carbon
import CoreGraphics
import FinderPackCore
import UserNotifications

@MainActor
enum PermissionStatus {
    static func requestAccessibility() {
        _ = CGRequestPostEventAccess()
    }

    static func snapshot() async -> SetupStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let notifications: PermissionState
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notifications = .allowed
        case .notDetermined: notifications = .notRequested
        case .denied: notifications = .denied
        @unknown default: notifications = .unknown
        }
        let automation = await Task.detached { finderAutomation(prompt: false) }.value
        return SetupStatus(accessibility: CGPreflightPostEventAccess(), finderAutomation: automation,
                           notifications: notifications)
    }

    nonisolated static func finderAutomation(prompt: Bool) -> PermissionState {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        let result = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, prompt)
        switch result {
        case noErr: return .allowed
        case OSStatus(errAEEventWouldRequireUserConsent): return .notRequested
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }
}
