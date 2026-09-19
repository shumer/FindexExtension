import AppKit
import CoreGraphics

@MainActor
enum FinderVisibility {
    private static var changing = false

    static func toggle() async throws {
        guard !changing else { throw failure("busy") }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            throw failure("hiddenFinderUnavailable")
        }
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            throw failure("hiddenPermission")
        }
        changing = true
        defer { changing = false }
        // Let the originating menu dismiss before delivering Finder's native command.
        try await Task.sleep(for: .milliseconds(150))
        guard !finder.isTerminated else { throw failure("hiddenFinderUnavailable") }
        // Finder handles this key equivalent only while its application is active.
        if !finder.isActive {
            guard finder.activate() else { throw failure("hiddenFailed") }
            for _ in 0..<20 {
                if finder.isActive { break }
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        guard finder.isActive else { throw failure("hiddenFailed") }
        // Target only Finder; never send the shortcut to whichever application is active.
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 47, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 47, keyDown: false) else {
            throw failure("hiddenFailed")
        }
        down.flags = [.maskCommand, .maskShift]
        up.flags = [.maskCommand, .maskShift]
        down.postToPid(finder.processIdentifier)
        try await Task.sleep(for: .milliseconds(40))
        up.postToPid(finder.processIdentifier)
        // Finder does not expose a confirmed live visibility state through its public API.
        try await Task.sleep(for: .milliseconds(150))
    }

    private static func failure(_ key: String) -> NSError {
        NSError(domain: "FinderPack.FinderVisibility", code: 1,
                userInfo: [NSLocalizedDescriptionKey: ProductText.value(key)])
    }
}
