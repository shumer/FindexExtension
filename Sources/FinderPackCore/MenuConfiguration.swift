import Foundation

public enum MenuCommand: String, CaseIterable, Sendable {
    case chooseDestination, cut, pasteFiles, pasteMove, moveHere, undoMove
    case favoriteDestinations, recentDestinations, hiddenFiles

    public static var identifiers: Set<String> {
        Set(allCases.map(\.rawValue) + PathStyle.allCases.map { "copy." + $0.rawValue })
    }
}

public struct FavoriteFolder: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var label: String
    public let url: URL

    public init(id: UUID = UUID(), url: URL, label: String = "") {
        self.id = id
        self.url = url
        self.label = label
    }

    public var title: String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent) : name
    }

    public static func validURL(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost") &&
            url.path.hasPrefix("/") && !url.path.utf8.contains(0) && url.path.utf8.count <= 4096
    }
}

public struct MenuDestination: Sendable, Equatable {
    public let url: URL
    public let title: String
    public let favorite: Bool
}

extension Preferences {
    public func shows(_ command: String) -> Bool { !disabledCommands.contains(command) }
    public func shows(_ command: MenuCommand) -> Bool { shows(command.rawValue) }

    public var visiblePathStyles: [PathStyle] {
        ([defaultPath] + PathStyle.allCases.filter { $0 != defaultPath }).filter { shows("copy." + $0.rawValue) }
    }

    public func menuDestinations(recent: [URL]) -> [MenuDestination] {
        var result: [MenuDestination] = []
        var paths = Set<String>()
        if shows(.favoriteDestinations) {
            for folder in favoriteFolders {
                paths.insert(folder.url.standardizedFileURL.path)
                result.append(MenuDestination(url: folder.url, title: folder.title, favorite: true))
            }
        }
        if shows(.recentDestinations) {
            for url in recent.prefix(5) where FavoriteFolder.validURL(url) && paths.insert(url.standardizedFileURL.path).inserted {
                result.append(MenuDestination(url: url, title: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent, favorite: false))
            }
        }
        return result
    }
}
