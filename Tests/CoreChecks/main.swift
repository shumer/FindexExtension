import Foundation
import FinderPackCore
import os

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
