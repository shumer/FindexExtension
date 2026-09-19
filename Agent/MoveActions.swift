import AppKit
import Foundation
import FinderPackCore
import os

@MainActor
final class MoveProgress: NSObject {
    let cancelled = OSAllocatedUnfairLock(initialState: false)
    private var window: NSWindow?
    private var delayed: Task<Void, Never>?
    private var label: NSTextField?

    func begin() {
        delayed = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            self?.show()
        }
    }
    private func show() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 130), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "FinderPack"
        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("Moving files. Originals are retained for recovery.", comment: ""))
        let progress = NSProgressIndicator()
        progress.style = .bar
        progress.isIndeterminate = true
        progress.startAnimation(nil)
        let button = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        let stack = NSStackView(views: [label, progress, button])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.frame = NSRect(x: 20, y: 20, width: 380, height: 90)
        window.contentView?.addSubview(stack)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        self.label = label
    }
    @objc private func cancel() {
        cancelled.withLock { $0 = true }
        label?.stringValue = NSLocalizedString("Stopping after the current safe step...", comment: "")
    }
    func end() { delayed?.cancel(); window?.close(); window = nil }
}

private struct MovePlan: Sendable {
    let source: URL
    let replace: Bool
}

actor MoveActions {
    static let shared = MoveActions()
    private var busy = false

    static func recent() -> [URL] {
        guard let root = try? SharedStorage.root(), let data = try? Data(contentsOf: root.appendingPathComponent("RecentDestinations.json")),
              data.count < 32_768, let urls = try? JSONDecoder().decode([URL].self, from: data) else { return [] }
        return Array(urls.filter { $0.isFileURL }.prefix(5))
    }

    func move(_ urls: [URL], destination: URL? = nil, copying: Bool = false) async throws {
        guard !busy else { throw MoveError.conflict }
        busy = true
        defer { busy = false }
        let folder: URL? = await MainActor.run {
            if let destination { return destination }
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = NSLocalizedString("Move Here", comment: "")
            NSApp.activate(ignoringOtherApps: true)
            return panel.runModal() == .OK ? panel.url : nil
        }
        guard let folder else { throw MoveError.cancelled }
        let paths = urls.map { $0.standardizedFileURL.path }.sorted()
        for pair in zip(paths, paths.dropFirst()) {
            guard pair.0 != pair.1, !pair.1.hasPrefix(pair.0 + "/") else { throw MoveError.unsafeLocation }
        }
        let collisions = await Task.detached {
            Set(urls.filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.lastPathComponent).path) })
        }.value
        let plan: [MovePlan] = try await MainActor.run {
            var plans: [MovePlan] = []
            var conflictPolicy: Int?
            for url in urls {
                if collisions.contains(url) {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("A file with this name already exists.", comment: "")
                    alert.informativeText = url.lastPathComponent
                    alert.addButton(withTitle: NSLocalizedString("Keep Both", comment: ""))
                    if !copying { alert.addButton(withTitle: NSLocalizedString("Replace and Keep Backup", comment: "")) }
                    alert.addButton(withTitle: NSLocalizedString("Skip", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                    alert.showsSuppressionButton = true
                    alert.suppressionButton?.title = NSLocalizedString("Apply to all conflicts", comment: "")
                    let result = conflictPolicy ?? (alert.runModal().rawValue - 1000)
                    if alert.suppressionButton?.state == .on { conflictPolicy = result }
                    if result == (copying ? 2 : 3) { throw MoveError.cancelled }
                    if result == (copying ? 1 : 2) { continue }
                    plans.append(MovePlan(source: url, replace: !copying && result == 1))
                } else { plans.append(MovePlan(source: url, replace: false)) }
            }
            return plans
        }
        let progress = await MoveProgress()
        let cancellation = progress.cancelled
        await progress.begin()
        let engine = MoveEngine(journal: try SharedStorage.root().appendingPathComponent("Moves", isDirectory: true))
        do {
            try await Task.detached {
                let batch = UUID()
                var completed: [MoveRecord] = []
                do {
                    for item in plan {
                        if copying { _ = try engine.copy(item.source, to: folder, cancelled: { cancellation.withLock { $0 } }) }
                        else {
                            if item.replace {
                                let backup = folder.appendingPathComponent(".finderpack-backup-" + UUID().uuidString)
                                try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
                                completed.append(try engine.move(folder.appendingPathComponent(item.source.lastPathComponent), to: backup, batch: batch))
                            }
                            completed.append(try engine.move(item.source, to: folder, batch: batch, cancelled: { cancellation.withLock { $0 } }))
                        }
                    }
                } catch {
                    for record in completed.reversed() { try? engine.undo(record) }
                    throw error
                }
            }.value
            let recent = [folder] + Self.recent().filter { $0.path != folder.path }
            try JSONEncoder().encode(Array(recent.prefix(5))).write(to: SharedStorage.root().appendingPathComponent("RecentDestinations.json"), options: .atomic)
            await progress.end()
        } catch {
            await progress.end()
            throw error
        }
    }

    func undo(id: String? = nil) async throws {
        guard !busy else { throw MoveError.conflict }
        busy = true
        defer { busy = false }
        let engine = MoveEngine(journal: try SharedStorage.root().appendingPathComponent("Moves", isDirectory: true))
        try await Task.detached {
            let records = try engine.records()
            guard let record = records.first(where: { ["moved", "retained", "copied", "restored-source"].contains($0.phase) && (id == nil || $0.id.uuidString == id) }) else {
                throw MoveError.invalidJournal
            }
            let group = record.batch ?? record.id
            for member in records.filter({ ($0.batch ?? $0.id) == group && ["moved", "retained", "copied", "restored-source"].contains($0.phase) }) {
                try engine.undo(member)
            }
        }.value
    }
}
