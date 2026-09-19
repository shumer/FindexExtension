import SwiftUI
import FinderPackCore

struct FavoriteFoldersView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Text("Pinned folders appear before recent folders in the Move menu. Removing a pin does not delete the folder.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Add Folders", action: model.addFavoriteFolders)
                    .disabled(model.preferences.favoriteFolders.count >= 20)
            }
            if model.preferences.favoriteFolders.isEmpty {
                Text("No pinned folders yet.").foregroundStyle(.secondary)
            }
            ForEach(model.preferences.favoriteFolders) { folder in
                Section {
                    HStack {
                        Image(systemName: "star")
                        TextField("Menu label", text: Binding(get: {
                            model.preferences.favoriteFolders.first { $0.id == folder.id }?.label ?? ""
                        }, set: { model.renameFavorite(folder.id, label: $0) }), prompt: Text(folder.title))
                        Button { model.reorderFavorite(folder.id, offset: -1) } label: { Image(systemName: "arrow.up") }
                            .help("Move up").disabled(model.preferences.favoriteFolders.first?.id == folder.id)
                        Button { model.reorderFavorite(folder.id, offset: 1) } label: { Image(systemName: "arrow.down") }
                            .help("Move down").disabled(model.preferences.favoriteFolders.last?.id == folder.id)
                        Button("Remove Pin") { model.preferences.favoriteFolders.removeAll { $0.id == folder.id } }
                    }
                    Text(folder.url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Text("Unavailable folders stay pinned. A move to a missing folder stops without choosing another destination.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Changes apply to new Finder menus within five seconds.").font(.callout).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
