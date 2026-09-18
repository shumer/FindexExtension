import Foundation
import Darwin

public enum TemplateError: Error, Equatable { case invalidName, unsupportedTemplate, exhaustedNames, writeFailed }

public struct TemplateStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func seed() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent(".seeded-v1")
        if manager.fileExists(atPath: marker.path) { return }
        let defaults = ["Text.txt": "", "Markdown.md": "# {{filename}}\n\n",
                        "PHP.php": "<?php\n", "JavaScript.js": "", "TypeScript.ts": "",
                        "JSON.json": "{}\n", "Shell.sh": "#!/bin/sh\n", ".gitignore": "", ".env": ""]
        for (name, text) in defaults {
            do { try Data(text.utf8).write(to: directory.appendingPathComponent(name), options: .withoutOverwriting) }
            catch CocoaError.fileWriteFileExists { continue }
        }
        try Data().write(to: marker, options: .atomic)
    }

    public func catalog() throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            .filter { url in
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                return url.lastPathComponent != ".seeded-v1" && ActionRequest.validName(url.lastPathComponent) &&
                    values.isRegularFile == true && values.isSymbolicLink != true
            }.map(\.lastPathComponent).sorted()
    }

    public func create(template: String, in destination: URL, date: Date = Date(), id: UUID = UUID()) throws -> URL {
        guard ActionRequest.validName(template) else { throw TemplateError.invalidName }
        let source = directory.appendingPathComponent(template)
        let sourceFD = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard sourceFD >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: sourceFD, closeOnDealloc: true)
        var attributes = stat()
        guard fstat(sourceFD, &attributes) == 0, attributes.st_mode & S_IFMT == S_IFREG,
              attributes.st_size <= 1_048_576 else { throw TemplateError.unsupportedTemplate }
        let original = try handle.read(upToCount: 1_048_577) ?? Data()
        guard original.count <= 1_048_576 else { throw TemplateError.unsupportedTemplate }
        let folderFD = open(destination.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard folderFD >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(folderFD) }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        for number in 1...10_000 {
            let name = Self.candidate(template, number: number)
            let fd = openat(folderFD, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o666) | (attributes.st_mode & 0o111))
            if fd < 0 {
                if errno == EEXIST { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            do {
                var content = original
                if var text = String(data: original, encoding: .utf8), !original.contains(0) {
                    let values = ["date": String(timestamp.prefix(10)), "datetime": timestamp,
                                  "year": String(timestamp.prefix(4)), "filename": name, "uuid": id.uuidString,
                                  "author": NSFullUserName()]
                    for (key, value) in values { text = text.replacingOccurrences(of: "{{\(key)}}", with: value) }
                    content = Data(text.utf8)
                }
                try output.write(contentsOf: content)
                try output.synchronize()
                try output.close()
                return destination.appendingPathComponent(name)
            } catch {
                // Never remove a pathname another process could have replaced after reservation.
                throw TemplateError.writeFailed
            }
        }
        throw TemplateError.exhaustedNames
    }

    public static func candidate(_ name: String, number: Int) -> String {
        guard number > 1 else { return name }
        let url = URL(fileURLWithPath: name)
        if name.hasPrefix("."), !name.dropFirst().contains(".") { return "\(name) \(number)" }
        let suffix = url.pathExtension
        return suffix.isEmpty ? "\(name) \(number)" : "\(url.deletingPathExtension().lastPathComponent) \(number).\(suffix)"
    }
}
