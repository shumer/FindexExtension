import AppKit
import FinderPackCore
import Carbon

@MainActor
enum ApplicationActions {
    static let supported = [
        ApplicationChoice(identifier: "com.apple.Terminal", name: "Terminal"),
        ApplicationChoice(identifier: "com.googlecode.iterm2", name: "iTerm2"),
        ApplicationChoice(identifier: "com.mitchellh.ghostty", name: "Ghostty"),
        ApplicationChoice(identifier: "dev.warp.Warp-Stable", name: "Warp"),
        ApplicationChoice(identifier: "org.alacritty", name: "Alacritty"),
        ApplicationChoice(identifier: "net.kovidgoyal.kitty", name: "kitty"),
        ApplicationChoice(identifier: "com.github.wez.wezterm", name: "WezTerm"),
        ApplicationChoice(identifier: "co.zeit.hyper", name: "Hyper"),
        ApplicationChoice(identifier: "org.neovim.nvim", name: "Neovim"),
        ApplicationChoice(identifier: "com.microsoft.VSCode", name: "Visual Studio Code"),
        ApplicationChoice(identifier: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        ApplicationChoice(identifier: "com.jetbrains.PhpStorm", name: "PhpStorm"),
        ApplicationChoice(identifier: "com.jetbrains.WebStorm", name: "WebStorm"),
        ApplicationChoice(identifier: "com.sublimetext.4", name: "Sublime Text"),
        ApplicationChoice(identifier: "dev.zed.Zed", name: "Zed")
    ]

    static func installed() -> [ApplicationChoice] {
        supported.filter { $0.identifier == "org.neovim.nvim" ? neovim() != nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.identifier) != nil }
    }

    private static func neovim() -> URL? {
        ["/opt/homebrew/bin/nvim", "/usr/local/bin/nvim"].first(where: FileManager.default.isExecutableFile(atPath:)).map { URL(fileURLWithPath: $0) }
    }

    static func open(_ identifier: String, urls: [URL]) async throws {
        guard supported.contains(where: { $0.identifier == identifier }), !urls.isEmpty else { throw MessageError.invalidContext }
        if identifier == "org.neovim.nvim" {
            guard let binary = neovim() else { throw MessageError.invalidContext }
            let command = "exec " + PathFormatter.shellQuote(binary.path) + " -- " + urls.map { PathFormatter.shellQuote($0.path) }.joined(separator: " ")
            try scriptCommand(command, iterm: false)
            return
        }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { throw MessageError.invalidContext }
        let terminals = Set(["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
                             "org.alacritty", "net.kovidgoyal.kitty", "com.github.wez.wezterm", "co.zeit.hyper"])
        guard terminals.contains(identifier) else {
            _ = try await NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        let folders = Array(Set(try urls.map { url in
            try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true ? url : url.deletingLastPathComponent()
        })).sorted { $0.path < $1.path }
        for folder in folders {
            let configuration = NSWorkspace.OpenConfiguration()
            switch identifier {
            case "com.googlecode.iterm2":
                let command = "cd -- " + PathFormatter.shellQuote(folder.path) + " && exec /bin/zsh -l"
                try scriptCommand("/bin/zsh -lc " + PathFormatter.shellQuote(command), iterm: true)
            case "dev.warp.Warp-Stable":
                var components = URLComponents()
                components.scheme = "warp"
                components.host = "action"
                components.path = "/new_window"
                components.queryItems = [URLQueryItem(name: "path", value: folder.path)]
                guard let url = components.url else { throw MessageError.invalidContext }
                _ = try await NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
            case "com.mitchellh.ghostty", "org.alacritty", "net.kovidgoyal.kitty", "com.github.wez.wezterm":
                configuration.createsNewApplicationInstance = true
                if identifier == "com.github.wez.wezterm" { configuration.arguments = ["start", "--cwd", folder.path] }
                else if identifier == "net.kovidgoyal.kitty" { configuration.arguments = ["--directory", folder.path] }
                else { configuration.arguments = ["--working-directory=" + folder.path] }
                _ = try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
            default:
                _ = try await NSWorkspace.shared.open([folder], withApplicationAt: app, configuration: configuration)
            }
        }
    }

    private static func scriptCommand(_ command: String, iterm: Bool) throws {
        let source = iterm ? """
        on runCommand(commandText)
            tell application "iTerm2"
                activate
                create window with default profile command commandText
            end tell
        end runCommand
        """ : """
        on runCommand(commandText)
            tell application "Terminal"
                activate
                do script commandText
            end tell
        end runCommand
        """
        guard let script = NSAppleScript(source: source) else { throw MessageError.invalidContext }
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite), eventID: AEEventID(kASSubroutineEvent),
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: "runcommand"), forKeyword: AEKeyword(keyASSubroutineName))
        let parameters = NSAppleEventDescriptor.list()
        parameters.insert(NSAppleEventDescriptor(string: command), at: 1)
        event.setParam(parameters, forKeyword: AEKeyword(keyDirectObject))
        var error: NSDictionary?
        script.executeAppleEvent(event, error: &error)
        if error != nil { throw ApplicationPermissionError() }
    }
}

private struct ApplicationPermissionError: LocalizedError {
    var errorDescription: String? {
        NSLocalizedString("Allow Automation for FinderPack in System Settings to open this terminal.", comment: "")
    }
}
