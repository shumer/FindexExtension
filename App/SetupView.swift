import SwiftUI
import FinderPackCore

struct SetupView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("File actions") {
                Label(LocalizedStringKey(model.setupReady ? "Ready for file actions" : "Finish setup to use Finder commands"),
                      systemImage: model.setupReady ? "checkmark.circle.fill" : "wrench.and.screwdriver")
                HStack {
                    status("Finder extension", value: model.extensionEnabled ? "Enabled" : "Not enabled", ready: model.extensionEnabled)
                    Spacer()
                    if !model.extensionEnabled { Button("Open Extension Settings", action: model.openExtensions) }
                }
                HStack {
                    status("Background helper", value: helperLabel, ready: model.helperResponding)
                    Spacer()
                    if model.checkingSetup { ProgressView().controlSize(.small) }
                    if model.agentRequiresApproval {
                        Button("Approve Background Access", action: model.openBackgroundSettings)
                    } else if !model.agentEnabled {
                        Button("Connect", action: model.register)
                    } else if !model.helperResponding {
                        Button("Retry", action: model.refreshSetup).disabled(model.checkingSetup)
                        Button("Background Settings", action: model.openBackgroundSettings)
                    }
                }
            }
            Section("Optional permissions") {
                Text("These permissions enable extra features. Copying paths, templates and moves do not require them.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        status("Hidden files", value: model.permissions.map { $0.accessibility ? "Allowed" : "Not allowed" } ?? "Unknown", ready: model.permissions?.accessibility == true)
                        Text("Accessibility lets FinderPackAgent send Finder's Show/Hide shortcut.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.permissions?.accessibility != true {
                        Button("Allow Accessibility") { model.requestPermission(.requestAccessibility) }
                            .disabled(!model.helperResponding || model.requestingPermission)
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        status("Finder shortcuts", value: permissionLabel(model.permissions?.finderAutomation), ready: model.permissions?.finderAutomation == .allowed)
                        Text("Automation lets shortcuts read the Finder selection and folder.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.permissions?.finderAutomation == .notRequested {
                        Button("Allow Finder Access") { model.requestPermission(.requestFinderAutomation) }
                            .disabled(model.requestingPermission)
                    } else if model.permissions?.finderAutomation != .allowed {
                        Button("Open Automation Settings") { model.openPrivacySettings("Privacy_Automation") }
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        status("Success notifications", value: permissionLabel(model.permissions?.notifications), ready: model.permissions?.notifications == .allowed)
                        Text("Errors remain visible even when notifications are disabled.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.permissions?.notifications == .notRequested {
                        Button("Allow Notifications", action: model.enableNotifications)
                            .disabled(model.requestingNotifications)
                    } else if model.permissions?.notifications != .allowed {
                        Button("Open Notification Settings", action: model.openNotificationSettings)
                    }
                }
                Text("Some terminal integrations also request Automation access when first used.").font(.caption).foregroundStyle(.secondary)
                if model.requestingPermission || model.requestingNotifications {
                    Text("Complete the permission request in macOS, then return here.").font(.callout)
                }
            }
            Button("Refresh Status", action: model.refreshSetup).disabled(model.checkingSetup)
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                model.refreshSetup()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    private var helperLabel: String {
        if model.agentRequiresApproval { return "Approval needed" }
        if !model.agentEnabled { return "Not connected" }
        if model.helperResponding { return "Responding" }
        return model.checkingSetup ? "Checking..." : "Not responding"
    }

    private func permissionLabel(_ state: PermissionState?) -> String {
        switch state {
        case .allowed: return "Allowed"
        case .notRequested: return "Not requested"
        case .denied: return "Not allowed"
        case .unknown, nil: return "Unknown"
        }
    }

    private func status(_ title: String, value: String, ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).font(.headline)
            Label(LocalizedStringKey(value), systemImage: ready ? "checkmark.circle" : "info.circle")
                .font(.callout).foregroundStyle(ready ? .green : .secondary)
        }
    }
}
