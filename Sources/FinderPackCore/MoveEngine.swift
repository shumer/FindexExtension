import Foundation
import CryptoKit
import Darwin

public enum MoveError: Error, Equatable {
    case unsafeLocation, changedSource, conflict, cancelled, invalidJournal
}

public struct MoveRecord: Codable, Sendable {
    public var created = Date()
    public var batch: UUID? = nil
    public var sourceIdentity: String? = nil
    public var commitIdentity: String? = nil
    public let id: UUID
    public let source: URL
    public let destination: URL
    public let retained: URL
    public let staging: URL
    public let fingerprint: String
    public var phase: String
}

public struct MoveEngine: Sendable {
    public let journal: URL
    public init(journal: URL) { self.journal = journal }

    public func records() throws -> [MoveRecord] {
        guard FileManager.default.fileExists(atPath: journal.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: journal, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { file in
                var record = try JSONDecoder().decode(MoveRecord.self, from: Data(contentsOf: file))
                guard record.source.isFileURL, record.destination.isFileURL else { throw MoveError.invalidJournal }
                let sourceExists = Self.identity(record.source) != nil
                if record.phase == "prepared", !sourceExists, let identity = record.sourceIdentity,
                   Self.identity(record.destination) == identity, try Self.fingerprint(record.destination) == record.fingerprint {
                    record.phase = "moved"
                }
                if record.phase == "copying", let identity = record.commitIdentity,
                   Self.identity(record.destination) == identity, try Self.fingerprint(record.destination) == record.fingerprint {
                    record.phase = "copied"
                }
                if record.phase == "copied", !sourceExists, let identity = record.sourceIdentity,
                   Self.identity(record.retained) == identity, try Self.fingerprint(record.retained) == record.fingerprint {
                    record.phase = "retained"
                }
                return record
            }.sorted { $0.created > $1.created }
    }

    public func move(_ source: URL, to folder: URL, batch: UUID? = nil, cancelled: @Sendable () -> Bool = { false }) throws -> MoveRecord {
        let manager = FileManager.default
        let source = source.standardizedFileURL
        let folder = folder.standardizedFileURL
        try validate(source: source, folder: folder)
        if cancelled() { throw MoveError.cancelled }
        let hash = try Self.fingerprint(source, cancelled: cancelled)
        let id = UUID()
        let retained = source.deletingLastPathComponent().appendingPathComponent(".finderpack-retained-" + id.uuidString)
        let staging = folder.appendingPathComponent(".finderpack-stage-" + id.uuidString)
        var record = MoveRecord(id: id, source: source, destination: folder.appendingPathComponent(source.lastPathComponent),
                                retained: retained, staging: staging, fingerprint: hash, phase: "prepared")
        try manager.createDirectory(at: journal, withIntermediateDirectories: true)
        for index in 1...10_000 {
            record = MoveRecord(id: id, source: source,
                                destination: folder.appendingPathComponent(TemplateStore.candidate(source.lastPathComponent, number: index)),
                                retained: retained, staging: staging, fingerprint: hash, phase: "prepared")
            record.sourceIdentity = Self.identity(source)
            record.batch = batch
            try save(record)
            if cancelled() { throw MoveError.cancelled }
            if renameatx_np(AT_FDCWD, source.path, AT_FDCWD, record.destination.path, UInt32(RENAME_EXCL)) == 0 {
                record.phase = "moved"
                try save(record)
                return record
            }
            if errno == EEXIST { continue }
            guard errno == EXDEV else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            record.phase = "copying"
            try save(record)
            try manager.copyItem(at: source, to: staging)
            guard try Self.fingerprint(staging, cancelled: cancelled) == hash,
                  try Self.fingerprint(source, cancelled: cancelled) == hash else { throw MoveError.changedSource }
            if cancelled() { throw MoveError.cancelled }
            record.commitIdentity = Self.identity(staging)
            try save(record)
            try exclusiveRename(staging, record.destination)
            record.phase = "copied"
            try save(record)
            // Keep the original on its volume until undo data is explicitly discarded.
            try exclusiveRename(source, retained)
            record.phase = "retained"
            try save(record)
            return record
        }
        throw MoveError.conflict
    }

    public func copy(_ source: URL, to folder: URL, cancelled: @Sendable () -> Bool = { false }) throws -> URL {
        try validate(source: source.standardizedFileURL, folder: folder.standardizedFileURL, allowSameFolder: true)
        let hash = try Self.fingerprint(source, cancelled: cancelled)
        let id = UUID()
        let staging = folder.appendingPathComponent(".finderpack-stage-" + id.uuidString)
        var record = MoveRecord(id: id, source: source, destination: folder.appendingPathComponent(source.lastPathComponent),
                                retained: source.deletingLastPathComponent().appendingPathComponent(".finderpack-retained-" + id.uuidString),
                                staging: staging, fingerprint: hash, phase: "copying")
        try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true)
        try save(record)
        try FileManager.default.copyItem(at: source, to: staging)
        guard try Self.fingerprint(staging, cancelled: cancelled) == hash,
              try Self.fingerprint(source, cancelled: cancelled) == hash else { throw MoveError.changedSource }
        for number in 1...10_000 {
            if cancelled() { throw MoveError.cancelled }
            let target = folder.appendingPathComponent(TemplateStore.candidate(source.lastPathComponent, number: number))
            record = MoveRecord(id: id, source: source, destination: target, retained: record.retained,
                                staging: staging, fingerprint: hash, phase: "copying")
            record.commitIdentity = Self.identity(staging)
            try save(record)
            do {
                try exclusiveRename(staging, target)
                record.phase = "copy-completed"
                try save(record)
                return target
            } catch MoveError.conflict { continue }
        }
        throw MoveError.conflict
    }

    public func undo(_ record: MoveRecord) throws {
        guard ["moved", "retained", "copied", "restored-source"].contains(record.phase),
              record.source.isFileURL, record.destination.isFileURL,
              record.source != record.destination,
              record.retained == record.source.deletingLastPathComponent().appendingPathComponent(".finderpack-retained-" + record.id.uuidString),
              record.staging == record.destination.deletingLastPathComponent().appendingPathComponent(".finderpack-stage-" + record.id.uuidString)
        else { throw MoveError.invalidJournal }
        guard try Self.fingerprint(record.destination) == record.fingerprint else { throw MoveError.changedSource }
        var updated = record
        if record.phase == "moved" {
            try exclusiveRename(record.destination, record.source)
        } else if record.phase == "copied" || record.phase == "restored-source" {
            guard try Self.fingerprint(record.source) == record.fingerprint else { throw MoveError.changedSource }
            try exclusiveRename(record.destination, record.staging)
        } else {
            guard try Self.fingerprint(record.retained) == record.fingerprint else { throw MoveError.changedSource }
            // Preserve the verified destination too, so interruption never loses either copy.
            try exclusiveRename(record.retained, record.source)
            updated.phase = "restored-source"
            try save(updated)
            try exclusiveRename(record.destination, record.staging)
        }
        updated.phase = "undone"
        try save(updated)
    }

    private static func identity(_ url: URL) -> String? {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return nil }
        return "\(metadata.st_dev):\(metadata.st_ino)"
    }

    private func exclusiveRename(_ source: URL, _ destination: URL) throws {
        guard renameatx_np(AT_FDCWD, source.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw MoveError.conflict }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func validate(source: URL, folder: URL, allowSameFolder: Bool = false) throws {
        let manager = FileManager.default
        guard source.isFileURL, folder.isFileURL, source.path != "/",
              source.deletingLastPathComponent().path != source.path,
              !["/System", "/Library", "/usr", "/bin", "/sbin", "/private/etc", "/private/var/db"].contains(where: { source.path == $0 || source.path.hasPrefix($0 + "/") }) else {
            throw MoveError.unsafeLocation
        }
        let volumes = manager.mountedVolumeURLs(includingResourceValuesForKeys: nil) ?? []
        guard !volumes.contains(where: { $0.path == source.path }), (allowSameFolder || source.deletingLastPathComponent().path != folder.path) else { throw MoveError.unsafeLocation }
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
        guard values.isDirectory == true, values.isSymbolicLink != true, values.isPackage != true else { throw MoveError.unsafeLocation }
        let actualFolder = folder.resolvingSymlinksInPath().pathComponents
        let resolvedSource = source.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(source.lastPathComponent)
        guard !["/System", "/Library", "/usr", "/bin", "/sbin", "/private/etc", "/private/var/db"].contains(where: { resolvedSource.path == $0 || resolvedSource.path.hasPrefix($0 + "/") }) else {
            throw MoveError.unsafeLocation
        }
        let actualSource = resolvedSource.pathComponents
        guard !actualFolder.starts(with: actualSource) else { throw MoveError.unsafeLocation }
    }

    private func save(_ record: MoveRecord) throws {
        try JSONEncoder().encode(record).write(to: journal.appendingPathComponent(record.id.uuidString + ".json"), options: .atomic)
    }

    public static func fingerprint(_ root: URL, cancelled: @Sendable () -> Bool = { false }) throws -> String {
        var hasher = SHA256()
        func visit(_ url: URL, relative: String) throws {
            if cancelled() { throw MoveError.cancelled }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let type = attributes[.type] as? FileAttributeType else { throw MoveError.changedSource }
            let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            hasher.update(data: Data("\(relative.utf8.count):\(relative):\(type.rawValue):\(mode):\(modified):".utf8))
            let attributeNamesSize = listxattr(url.path, nil, 0, XATTR_NOFOLLOW)
            if attributeNamesSize < 0 && errno != ENOTSUP { throw MoveError.changedSource }
            if attributeNamesSize > 0 {
                var names = [CChar](repeating: 0, count: attributeNamesSize)
                guard listxattr(url.path, &names, names.count, XATTR_NOFOLLOW) == attributeNamesSize else { throw MoveError.changedSource }
                let keys = names.split(separator: 0).map { String(decoding: $0.map { UInt8(bitPattern: $0) }, as: UTF8.self) }.sorted()
                for key in keys {
                    let size = getxattr(url.path, key, nil, 0, 0, XATTR_NOFOLLOW)
                    guard size >= 0, size <= 16_777_216 else { throw MoveError.changedSource }
                    var bytes = [UInt8](repeating: 0, count: size)
                    guard getxattr(url.path, key, &bytes, size, 0, XATTR_NOFOLLOW) == size else { throw MoveError.changedSource }
                    hasher.update(data: Data("\(key.utf8.count):\(key):\(size):".utf8))
                    hasher.update(data: Data(bytes))
                }
            }
            let acl = type == .typeSymbolicLink ? acl_get_link_np(url.path, ACL_TYPE_EXTENDED) : acl_get_file(url.path, ACL_TYPE_EXTENDED)
            if let acl {
                defer { acl_free(UnsafeMutableRawPointer(acl)) }
                var length = 0
                guard let text = acl_to_text(acl, &length) else { throw MoveError.changedSource }
                defer { acl_free(text) }
                hasher.update(data: Data(bytes: text, count: length))
            } else if errno != ENOTSUP && errno != ENOENT { throw MoveError.changedSource }
            if type == .typeSymbolicLink {
                hasher.update(data: Data(try FileManager.default.destinationOfSymbolicLink(atPath: url.path).utf8))
            } else if type == .typeDirectory {
                let children = try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
                for child in children { try visit(url.appendingPathComponent(child), relative: relative + "/" + child) }
            } else if type == .typeRegular {
                hasher.update(data: Data("size:\(attributes[.size] as? NSNumber ?? 0):".utf8))
                let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
                guard fd >= 0 else { throw MoveError.changedSource }
                let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
                while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty {
                    if cancelled() { throw MoveError.cancelled }
                    hasher.update(data: bytes)
                }
            } else { throw MoveError.unsafeLocation }
        }
        try visit(root, relative: "")
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
