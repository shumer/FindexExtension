import AppKit
import FinderPackCore

@MainActor
enum FileClipboard {
    private static var cutChangeCount: Int?
    private static var cutURLs: [URL] = []

    static func cut(_ urls: [URL]) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls.map { $0 as NSURL }) else { throw MessageError.invalidContext }
        cutURLs = urls
        cutChangeCount = pasteboard.changeCount
    }

    static func read(moving: Bool) throws -> [URL] {
        let pasteboard = NSPasteboard.general
        if moving {
            guard cutChangeCount == pasteboard.changeCount, !cutURLs.isEmpty else { throw MessageError.invalidContext }
            let urls = cutURLs
            cutURLs = []
            cutChangeCount = nil
            return urls
        }
        guard let values = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !values.isEmpty, values.count <= 10_000 else { throw MessageError.invalidContext }
        return values
    }
}
