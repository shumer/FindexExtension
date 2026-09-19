import SwiftUI
import FinderPackCore
import UniformTypeIdentifiers

private enum SettingsSection: String, CaseIterable, Identifiable {
    case menu = "Menu", templates = "Templates", applications = "Applications"
    case shortcuts = "Shortcuts", feedback = "Feedback", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .menu: return "list.bullet"
        case .templates: return "doc.on.doc"
        case .applications: return "app.badge"
        case .shortcuts: return "keyboard"
        case .feedback: return "bell"
        case .about: return "info.circle"
        }
    }
}

@MainActor
private final class SettingsNavigation: ObservableObject {
    @Published var section = SettingsSection.menu
    @Published var confirmRemoval = false
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()
    @StateObject private var navigation = SettingsNavigation()
    private var section: SettingsSection { navigation.section }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $navigation.section) { item in
                Label(LocalizedStringKey(item.rawValue), systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey(section.rawValue)).font(.title2)
                if !model.extensionEnabled || !model.agentEnabled { setup }
                switch section {
                case .menu: menu
                case .templates: templates
                case .applications:
                    ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                    Toggle("Open In", isOn: $model.preferences.showOpen)
                    Picker("Preferred application", selection: $model.preferences.preferredApplication) {
                        ForEach(model.applications, id: \.identifier) { application in
                            Text(application.name).tag(application.identifier)
                        }
                    }
                    ForEach(model.applications, id: \.identifier) { application in
                        Toggle(application.name, isOn: Binding(get: {
                            !model.preferences.disabledApplications.contains(application.identifier)
                        }, set: { enabled in
                            model.preferences.disabledApplications.removeAll { $0 == application.identifier }
                            if !enabled { model.preferences.disabledApplications.append(application.identifier) }
                        }))
                    }
                    Text("Installed supported applications appear in Finder automatically. Terminal opens the containing folder; editors receive selected files.").font(.callout)
                    }
                    }
                case .shortcuts:
                    Text("No shortcuts are assigned by default.").foregroundStyle(.secondary)
                    ForEach(["copy", "new"], id: \.self) { action in
                        HStack {
                            Text(ProductText.value(action))
                            Spacer()
                            ShortcutRecorder(label: NSLocalizedString("Record Shortcut", comment: ""),
                                             value: model.preferences.shortcuts.first { $0.action == action }, changed: { shortcut in
                                model.preferences.shortcuts.removeAll { $0.action == action }
                                if let shortcut { model.preferences.shortcuts.append(shortcut) }
                            }, action: action).frame(width: 200, height: 28)
                            Button("Clear") { model.preferences.shortcuts.removeAll { $0.action == action } }
                        }
                        Toggle("Use outside Finder", isOn: Binding(get: {
                            model.preferences.shortcuts.first { $0.action == action }?.global ?? false
                        }, set: { global in
                            if let index = model.preferences.shortcuts.firstIndex(where: { $0.action == action }) {
                                model.preferences.shortcuts[index].global = global
                            }
                        })).disabled(!model.preferences.shortcuts.contains { $0.action == action })
                    }
                    Text("Shortcuts work while Finder is active and request Automation permission on first use.").font(.callout)
                    Text("Outside Finder, shortcuts use the frontmost Finder window, not the active application.").font(.callout)
                case .feedback: feedback
                case .about: about
                }
                Spacer(minLength: 0)
                if !model.message.isEmpty { Text(model.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 580)
        .onChange(of: model.preferences) { _, _ in model.savePreferences() }
        .alert("FinderPack", isPresented: Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })) {
            Button("OK") { model.failure = nil }
        } message: { Text(model.failure ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.reload() }
    }

    private var setup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(LocalizedStringKey(model.extensionEnabled ? "Extension enabled" : "Enable the Finder extension"), systemImage: model.extensionEnabled ? "checkmark.circle" : "puzzlepiece.extension")
                if !model.extensionEnabled { Button("Open Extension Settings", action: model.openExtensions) }
                Label(LocalizedStringKey(model.agentEnabled ? "Background helper connected" : "Connect the background helper"), systemImage: model.agentEnabled ? "checkmark.circle" : "gearshape")
                if !model.agentEnabled {
                    HStack { Button("Connect", action: model.register); Button("Background Settings", action: model.openBackgroundSettings) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var menu: some View {
        Form {
            Toggle("Copy Path", isOn: $model.preferences.showCopy)
            Toggle("New File", isOn: $model.preferences.showNew)
            Toggle("Move", isOn: $model.preferences.showMove)
            Section("Group order") {
                ForEach(model.preferences.groupOrder, id: \.self) { group in
                    HStack {
                        Text(ProductText.value(group))
                        Spacer()
                        Button { reorderGroup(group, offset: -1) } label: { Image(systemName: "arrow.up") }.help("Move up")
                        Button { reorderGroup(group, offset: 1) } label: { Image(systemName: "arrow.down") }.help("Move down")
                    }
                }
            }
            Picker("First path format", selection: $model.preferences.defaultPath) {
                ForEach(PathStyle.allCases.filter { $0 != .gitRelative }, id: \.self) { style in
                    Text(ProductText.value(style.rawValue)).tag(style)
                }
            }
            Picker("Multiple paths", selection: $model.preferences.separator) {
                Text("One per line").tag(PathSeparator.newline)
                Text("Space separated").tag(PathSeparator.space)
                Text("Comma separated").tag(PathSeparator.comma)
            }
            if !model.moves.isEmpty {
                Section("Recent file operations") {
                    ForEach(model.moves, id: \.id) { record in
                        VStack(alignment: .leading) {
                            Text(record.source.lastPathComponent).font(.headline)
                            Text(record.destination.path).font(.caption).textSelection(.enabled)
                            HStack {
                                Button("Reveal", action: { model.revealMove(record) })
                                Button("Undo Move", action: { model.undoMove(record) }).disabled(!["moved", "retained", "copied", "restored-source"].contains(record.phase))
                            }
                        }
                    }
                    Text("Recovery copies are kept until you remove them. Reveal shows their locations.").font(.callout)
                }
            }
            Text("Changes apply to new Finder menus within five seconds.").font(.callout).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }

    private func reorderGroup(_ group: String, offset: Int) {
        guard let index = model.preferences.groupOrder.firstIndex(of: group), model.preferences.groupOrder.indices.contains(index + offset) else { return }
        model.preferences.groupOrder.swapAt(index, index + offset)
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("New", action: model.addTemplate)
                Button("Import", action: model.importTemplates)
                Button("Reveal", action: model.revealTemplates)
                Button("Reload") { model.reload(); model.select(model.selected) }
                Spacer()
                Button(role: .destructive) { navigation.confirmRemoval = true } label: { Image(systemName: "trash") }
                    .help("Move template to Trash").disabled(model.selected == nil)
            }
            .confirmationDialog("Move template to Trash?", isPresented: $navigation.confirmRemoval) {
                Button("Move to Trash", role: .destructive, action: model.removeTemplate)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack {
                    List(model.templates, id: \.self, selection: Binding(get: { model.selected }, set: { name in model.select(name) })) { name in
                        Text(model.preferences.label(for: name))
                    }.frame(minWidth: 150, idealWidth: 170, maxWidth: 200)
                    HStack {
                        Button { model.reorder(-1) } label: { Image(systemName: "arrow.up") }.help("Move up")
                        Button { model.reorder(1) } label: { Image(systemName: "arrow.down") }.help("Move down")
                    }.disabled(model.selected == nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let selected = model.selected {
                        Text(selected).font(.headline)
                        TextField("Menu label", text: metadata(selected, \.label))
                        Picker("Symbol", selection: metadata(selected, \.symbol)) {
                            ForEach(["doc", "doc.text", "chevron.left.forwardslash.chevron.right", "terminal", "note.text"], id: \.self) { symbol in
                                Label(symbol, systemImage: symbol).tag(symbol)
                            }
                        }
                        TextEditor(text: $model.content).font(.system(.body, design: .monospaced)).disabled(!model.editable)
                            .accessibilityLabel("Template content").border(.separator)
                        Button("Save Content", action: model.saveTemplate).disabled(!model.editable)
                    } else { Text("Select a template to edit.").foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(minHeight: 220)
            TextField("Author for templates", text: $model.preferences.author)
            Text("Placeholders: {{date}}, {{datetime}}, {{filename}}, {{author}}, {{year}}, {{uuid}}").font(.callout).textSelection(.enabled)
        }
        .dropDestination(for: URL.self) { urls, _ in model.importURLs(urls); return true }
    }

    private func metadata(_ name: String, _ field: WritableKeyPath<TemplateMetadata, String>) -> Binding<String> {
        Binding(get: { (model.preferences.templates[name] ?? TemplateMetadata())[keyPath: field] }, set: { value in
            var metadata = model.preferences.templates[name] ?? TemplateMetadata()
            metadata[keyPath: field] = value
            model.preferences.templates[name] = metadata
        })
    }

    private var feedback: some View {
        Form {
            Toggle("Show success notifications", isOn: $model.preferences.notifySuccess)
            Button("Allow Notifications", action: model.enableNotifications)
            Text("Errors are always shown. Notification permission does not affect file actions.").font(.callout)
        }.formStyle(.grouped)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FinderPack").font(.title)
            Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
            Link("Project and releases", destination: URL(string: "https://github.com/shumer/FindexExtension")!)
            Button("Check for Updates", action: UpdateController.shared.check)
            Button("Check Connection", action: model.checkConnection)
            Button("Refresh Status", action: model.reload)
            Button("Disconnect Helper", action: model.unregister)
            Text("Disconnect the helper before removing FinderPack from Applications.").font(.callout)
        }
    }
}
