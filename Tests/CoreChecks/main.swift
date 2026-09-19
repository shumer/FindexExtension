import Foundation
import FinderPackCore
import os
import Darwin

var checks = 0
@MainActor func expect(_ value: Bool, _ label: String) throws {
    guard value else { throw NSError(domain: "CoreChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
    checks += 1
}
@MainActor func expectError(_ expected: MessageError, data: Data) throws {
    do {
        _ = try DiagnosticRequest.decode(data)
        try expect(false, "Message should be rejected")
    } catch let error as MessageError {
        try expect(error == expected, "Unexpected message error")
    }
}

let base = URL(fileURLWithPath: "/Users/example/project", isDirectory: true)
let file = base.appendingPathComponent("My File.swift")
try expect(try PathFormatter.format(file, as: .posix) == "/Users/example/project/My File.swift", "POSIX path")
try expect(try PathFormatter.format(file, as: .relative, directory: base) == "My File.swift", "Relative path")
try expect(try PathFormatter.format(base, as: .relative, directory: base) == ".", "Same directory")
try expect(try PathFormatter.format(file, as: .relative, directory: base.appendingPathComponent("other")) == "../My File.swift", "Sibling relative path")
try expect(try PathFormatter.format(file, as: .gitRelative, gitRoot: base) == "My File.swift", "Git-relative path")
try expect(try PathFormatter.format(file, as: .homeRelative, home: base) == "~/My File.swift", "Home path")
try expect(try PathFormatter.format(URL(fileURLWithPath: "/Users/example/project-other/a"), as: .homeRelative, home: base) == "/Users/example/project-other/a", "Component boundary")
try expect(try PathFormatter.format(base.appendingPathComponent(".gitignore"), as: .stem) == ".gitignore", "Dotfile stem")
try expect(try PathFormatter.format(file, as: .stem) == "My File", "Stem")
try expect(try PathFormatter.format(file, as: .name) == "My File.swift", "Name")
try expect(try PathFormatter.format(file, as: .parent) == base.path, "Parent")
let encoded = try PathFormatter.format(file, as: .fileURL)
try expect(URL(string: encoded)?.path == file.path && encoded.contains("%20"), "File URL encoding")

do {
    _ = try PathFormatter.format(URL(fileURLWithPath: "/outside"), as: .gitRelative, gitRoot: base)
    try expect(false, "Outside git root must fail")
} catch PathFormattingError.outsideGitRoot { checks += 1 }

let names = ["plain", "a b", "a'b", "a\"b", "$HOME", "$(touch INJECTED)", "`id`", "a\\b", "line\nbreak", "emoji-😀", "עברית", "", "--flag"]
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let command = "printf '%s\\0' " + names.map(PathFormatter.shellQuote).joined(separator: " ")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/sh")
process.arguments = ["-c", command]
process.currentDirectoryURL = temporary
let output = Pipe()
process.standardOutput = output
try process.run()
let bytes = output.fileHandleForReading.readDataToEndOfFile()
process.waitUntilExit()
try expect(process.terminationStatus == 0, "Shell exits successfully")
try expect(bytes == Data((names.joined(separator: "\0") + "\0").utf8), "Exact shell argument round trip")
try expect(!FileManager.default.fileExists(atPath: temporary.appendingPathComponent("INJECTED").path), "No command substitution")

let actualNames = names.filter { !$0.isEmpty }
let actualPaths = actualNames.map { temporary.appendingPathComponent($0).path }
for path in actualPaths { try Data("sample".utf8).write(to: URL(fileURLWithPath: path)) }
let fileCheck = Process()
fileCheck.executableURL = URL(fileURLWithPath: "/bin/sh")
fileCheck.arguments = ["-c", "for item in " + actualPaths.map(PathFormatter.shellQuote).joined(separator: " ") + "; do test -f \"$item\" || exit 1; done"]
try fileCheck.run()
fileCheck.waitUntilExit()
try expect(fileCheck.terminationStatus == 0, "Shell accesses exact files with hostile names")

let request = DiagnosticRequest(selectedURLs: [file], targetedURL: base)
let data = try JSONEncoder().encode(request)
try expect(try DiagnosticRequest.decode(data) == request, "Request round trip")
var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
json["version"] = 2
try expectError(.unsupportedVersion, data: JSONSerialization.data(withJSONObject: json))
try expectError(.tooLarge, data: Data(repeating: 32, count: 1_048_577))
try expectError(.invalidContext, data: JSONEncoder().encode(DiagnosticRequest(selectedURLs: [URL(string: "https://example.com")!])))
try expectError(.invalidContext, data: JSONEncoder().encode(DiagnosticRequest(selectedURLs: Array(repeating: file, count: 10_001))))
print("Passed \(checks) core checks.")

let store = TemplateStore(directory: temporary.appendingPathComponent("Templates"))
try store.seed()
try expect(try store.catalog().count == 9, "Seed nine templates")
try FileManager.default.removeItem(at: store.directory.appendingPathComponent("PHP.php"))
try store.seed()
try expect(try !store.catalog().contains("PHP.php"), "Deleted templates stay deleted")
let destination = temporary.appendingPathComponent("Destination")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let first = try store.create(template: "Markdown.md", in: destination)
let second = try store.create(template: "Markdown.md", in: destination)
try expect(first.lastPathComponent == "Markdown.md" && second.lastPathComponent == "Markdown 2.md", "Non-destructive numbered collision")
try expect(try String(contentsOf: second, encoding: .utf8).contains("Markdown 2.md"), "Substitute actual reserved filename")
try expect(try String(contentsOf: first, encoding: .utf8).contains("Markdown.md"), "Original file remains unchanged")
try expect(TemplateStore.candidate(".env", number: 2) == ".env 2", "Dotfile collision")
try FileManager.default.createSymbolicLink(atPath: destination.appendingPathComponent("Text.txt").path, withDestinationPath: first.path)
let afterLink = try store.create(template: "Text.txt", in: destination)
try expect(afterLink.lastPathComponent == "Text 2.txt", "Never overwrite or follow destination symlink")
try FileManager.default.createSymbolicLink(atPath: store.directory.appendingPathComponent("Link.txt").path, withDestinationPath: first.path)
try expect(try !store.catalog().contains("Link.txt"), "Catalog excludes symlinks")
do {
    _ = try store.create(template: "Link.txt", in: destination)
    try expect(false, "Source symlink must fail")
} catch is POSIXError { checks += 1 }
do {
    _ = try store.create(template: "../outside", in: destination)
    try expect(false, "Template traversal must fail")
} catch TemplateError.invalidName { checks += 1 }
let binary = Data([0, 255, 1, 2, 3])
try binary.write(to: store.directory.appendingPathComponent("Binary.dat"))
let binaryCopy = try store.create(template: "Binary.dat", in: destination)
try expect(try Data(contentsOf: binaryCopy) == binary, "Binary bytes remain unchanged")
let action = ActionRequest(action: .newFile, target: destination, template: "Text.txt")
try expect(try ActionRequest.decode(JSONEncoder().encode(action)) == action, "Action request round trip")
for invalid in [ActionRequest(action: .newFile, target: destination, template: "../escape"),
                ActionRequest(action: .copyPath, urls: [], style: .posix),
                ActionRequest(action: .copyPath, urls: [URL(string: "https://example.com")!], style: .posix)] {
    do {
        _ = try ActionRequest.decode(JSONEncoder().encode(invalid))
        try expect(false, "Reject invalid action context")
    } catch MessageError.invalidContext { checks += 1 }
}
print("Passed \(checks) total core checks.")

let failures = OSAllocatedUnfairLock(initialState: 0)
DispatchQueue.concurrentPerform(iterations: 20) { _ in
    do { _ = try store.create(template: "JSON.json", in: destination) }
    catch { failures.withLock { $0 += 1 } }
}
try expect(failures.withLock { $0 } == 0, "Concurrent requests all complete")
let createdJSON = try FileManager.default.contentsOfDirectory(atPath: destination.path).filter { $0.hasSuffix(".json") }
try expect(createdJSON.count == 20, "Concurrent requests reserve distinct filenames")
let alias = temporary.appendingPathComponent("LinkedDestination")
try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: destination.path)
do {
    _ = try store.create(template: "Text.txt", in: alias)
    try expect(false, "Linked destination must fail")
} catch is POSIXError { checks += 1 }
print("Passed \(checks) total checks including concurrent creation.")

let prefsStore = PreferencesStore(url: temporary.appendingPathComponent("Preferences.json"))
var prefs = Preferences()
prefs.separator = .comma
prefs.author = "Example"
prefs.templates["Text.txt"] = TemplateMetadata(label: "Notes", symbol: "note.text", order: -1)
try prefsStore.save(prefs)
try expect(try prefsStore.load() == prefs, "Atomic preferences round trip")
try expect(prefs.sorted(["JSON.json", "Text.txt"]).first == "Text.txt", "Template metadata order")
let repository = temporary.appendingPathComponent("Repository")
try FileManager.default.createDirectory(at: repository.appendingPathComponent("nested"), withIntermediateDirectories: true)
try Data("gitdir: /example/worktree".utf8).write(to: repository.appendingPathComponent(".git"))
try expect(GitDiscovery.root(containing: repository.appendingPathComponent("nested"))?.path == repository.path, "Worktree git marker discovery")
let importFolder = temporary.appendingPathComponent("Imported")
try FileManager.default.createDirectory(at: importFolder, withIntermediateDirectories: true)
let imported = try store.create(template: "Markdown.md", in: importFolder, expandPlaceholders: false)
try expect(try String(contentsOf: imported, encoding: .utf8).contains("{{filename}}"), "Import preserves placeholders")

let moveSource = temporary.appendingPathComponent("MoveSource")
let moveTarget = temporary.appendingPathComponent("MoveTarget")
try FileManager.default.createDirectory(at: moveSource, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: moveTarget, withIntermediateDirectories: true)
let moving = moveSource.appendingPathComponent("sample.txt")
try Data("original".utf8).write(to: moving)
try Data("existing".utf8).write(to: moveTarget.appendingPathComponent("sample.txt"))
let engine = MoveEngine(journal: temporary.appendingPathComponent("MoveJournal"))
let move = try engine.move(moving, to: moveTarget)
try expect(move.destination.lastPathComponent == "sample 2.txt", "Move keeps existing destination")
try expect(!FileManager.default.fileExists(atPath: moving.path), "Same-volume move removes source name")
try expect(try String(contentsOf: moveTarget.appendingPathComponent("sample.txt"), encoding: .utf8) == "existing", "Move preserves pre-existing data")
try engine.undo(move)
try expect(try String(contentsOf: moving, encoding: .utf8) == "original", "Undo restores original")
let changed = try engine.move(moving, to: moveTarget)
try Data("edited after move".utf8).write(to: changed.destination)
do {
    try engine.undo(changed)
    try expect(false, "Undo must refuse changed destination")
} catch MoveError.changedSource { checks += 1 }
let tree = moveSource.appendingPathComponent("Tree")
try FileManager.default.createDirectory(at: tree.appendingPathComponent("Child"), withIntermediateDirectories: true)
do {
    _ = try engine.move(tree, to: tree.appendingPathComponent("Child"))
    try expect(false, "Move must reject a descendant")
} catch MoveError.unsafeLocation { checks += 1 }
do {
    _ = try engine.move(tree, to: moveTarget, cancelled: { true })
    try expect(false, "Cancelled move must stop")
} catch MoveError.cancelled { checks += 1 }
try expect(FileManager.default.fileExists(atPath: tree.path), "Cancelled move preserves source")
let linkSource = moveSource.appendingPathComponent("Shortcut")
try FileManager.default.createSymbolicLink(atPath: linkSource.path, withDestinationPath: tree.path)
let movedLink = try engine.move(linkSource, to: moveTarget)
try expect(try FileManager.default.destinationOfSymbolicLink(atPath: movedLink.destination.path) == tree.path, "Move preserves symlink itself")
try engine.undo(movedLink)
print("Passed \(checks) checks including preferences, git discovery and move recovery.")

let utf16 = Data([0xff, 0xfe]) + "Hello {{author}}".data(using: .utf16LittleEndian)!
let rendered = TemplateRendering.render(utf16, values: ["author": "{{date}}", "date": "unexpected"])
try expect(String(data: rendered.dropFirst(2), encoding: .utf16LittleEndian) == "Hello {{date}}", "UTF-16 preservation and single-pass substitution")
let treeTemplate = store.directory.appendingPathComponent("Project")
try FileManager.default.createDirectory(at: treeTemplate.appendingPathComponent("Sources"), withIntermediateDirectories: true)
try Data("{{year}}".utf8).write(to: treeTemplate.appendingPathComponent("Sources/main.txt"))
let project = try store.create(template: "Project", in: destination, date: Date(timeIntervalSince1970: 0))
try expect(try String(contentsOf: project.appendingPathComponent("Sources/main.txt"), encoding: .utf8) == "1970", "Directory template rendering")
let copied = try engine.copy(tree, to: moveTarget)
try expect(FileManager.default.fileExists(atPath: tree.path) && FileManager.default.fileExists(atPath: copied.path), "Copy preserves its source")
print("Passed \(checks) checks including template trees and encodings.")

if let mount = ProcessInfo.processInfo.environment["FINDERPACK_TEST_VOLUME"] {
    let remote = URL(fileURLWithPath: mount).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: remote) }
    let source = moveSource.appendingPathComponent("CrossVolume.txt")
    try Data("cross-volume integrity".utf8).write(to: source)
    let attribute = Data("preserved metadata".utf8)
    let attributeResult = attribute.withUnsafeBytes { setxattr(source.path, "com.shumer.finderpack.test", $0.baseAddress, $0.count, 0, 0) }
    try expect(attributeResult == 0, "Create cross-volume metadata fixture")
    let aclProcess = Process()
    aclProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
    aclProcess.arguments = ["+a", "user:\(NSUserName()) allow read", source.path]
    try aclProcess.run()
    aclProcess.waitUntilExit()
    try expect(aclProcess.terminationStatus == 0, "Create cross-volume ACL fixture")
    let record = try engine.move(source, to: remote)
    try expect(record.phase == "retained", "Cross-volume move keeps recoverable original")
    try expect(try Data(contentsOf: record.retained) == Data(contentsOf: record.destination), "Cross-volume copies match")
    try engine.undo(record)
    try expect(try String(contentsOf: source, encoding: .utf8) == "cross-volume integrity", "Cross-volume undo restores source")
    try expect(!FileManager.default.fileExists(atPath: record.destination.path), "Undo removes active destination name")
    print("Passed \(checks) checks including a separate mounted volume.")
}

let recoverSource = moveSource.appendingPathComponent("Recover.txt")
try Data("recoverable".utf8).write(to: recoverSource)
var interrupted = try engine.move(recoverSource, to: moveTarget)
interrupted.phase = "prepared"
try JSONEncoder().encode(interrupted).write(to: engine.journal.appendingPathComponent(interrupted.id.uuidString + ".json"), options: .atomic)
let recovered = try engine.records().first { $0.id == interrupted.id }!
try expect(recovered.phase == "moved", "Recover rename interrupted before journal completion")
try engine.undo(recovered)
try expect(try String(contentsOf: recoverSource, encoding: .utf8) == "recoverable", "Recovered move can be undone")
var oldRequest = try JSONSerialization.jsonObject(with: JSONEncoder().encode(action)) as! [String: Any]
oldRequest["created"] = 0
let stale = try JSONSerialization.data(withJSONObject: oldRequest)
do {
    _ = try ActionRequest.decode(stale)
    try expect(false, "Old action request must not replay after receipt cleanup")
} catch MessageError.invalidContext { checks += 1 }
print("Passed \(checks) total checks including interrupted journals and stale requests.")

let occupiedSource = moveSource.appendingPathComponent("Occupied.txt")
try Data("original".utf8).write(to: occupiedSource)
let occupiedRecord = try engine.move(occupiedSource, to: moveTarget)
try Data("new original path occupant".utf8).write(to: occupiedSource)
do {
    try engine.undo(occupiedRecord)
    try expect(false, "Undo must not overwrite a new original-path occupant")
} catch MoveError.conflict { checks += 1 }
try expect(try String(contentsOf: occupiedSource, encoding: .utf8) == "new original path occupant", "Undo preserves the new occupant")
try expect(try String(contentsOf: occupiedRecord.destination, encoding: .utf8) == "original", "Blocked undo preserves moved content")
let replaceSource = moveSource.appendingPathComponent("Replacement.txt")
let replaceDestination = moveTarget.appendingPathComponent("Replacement.txt")
let backupFolder = moveTarget.appendingPathComponent("ReplacementBackup")
try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
try Data("new".utf8).write(to: replaceSource)
try Data("old".utf8).write(to: replaceDestination)
let batch = UUID()
let backupRecord = try engine.move(replaceDestination, to: backupFolder, batch: batch)
let replacementRecord = try engine.move(replaceSource, to: moveTarget, batch: batch)
try engine.undo(replacementRecord)
try engine.undo(backupRecord)
try expect(try String(contentsOf: replaceSource, encoding: .utf8) == "new", "Replacement undo restores incoming file")
try expect(try String(contentsOf: replaceDestination, encoding: .utf8) == "old", "Replacement undo restores replaced file")
print("Passed \(checks) total checks including occupied-path and replacement recovery.")


let visibilityRequest = ActionRequest(action: .toggleHiddenFiles)
try expect(try ActionRequest.decode(JSONEncoder().encode(visibilityRequest)) == visibilityRequest,
           "Hidden-file command round trip preserves its receipt identity")
for invalid in [
    ActionRequest(action: .toggleHiddenFiles, urls: [file]),
    ActionRequest(action: .toggleHiddenFiles, target: base),
    ActionRequest(action: .toggleHiddenFiles, style: .posix),
    ActionRequest(action: .toggleHiddenFiles, template: "Text.txt"),
    ActionRequest(action: .toggleHiddenFiles, application: "com.apple.finder"),
    ActionRequest(action: .toggleHiddenFiles, destination: base)
] {
    do {
        _ = try ActionRequest.decode(JSONEncoder().encode(invalid))
        try expect(false, "Reject file context on a fixed Finder shortcut command")
    } catch MessageError.invalidContext { checks += 1 }
}
let oldReply = ActionReply(requestID: UUID(), succeeded: true)
try expect(try JSONDecoder().decode(ActionReply.self, from: JSONEncoder().encode(oldReply)).canToggleHiddenFiles == nil,
           "An older helper does not advertise the new command")
let capableReply = ActionReply(requestID: UUID(), succeeded: true, canToggleHiddenFiles: true)
try expect(try JSONDecoder().decode(ActionReply.self, from: JSONEncoder().encode(capableReply)).canToggleHiddenFiles == true,
           "New helper advertises command support independently of Finder visibility")
print("Passed \(checks) total checks including the Finder shortcut contract.")
