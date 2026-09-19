import AppKit
import Sparkle
import ServiceManagement

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateController()
    private var controller: SPUStandardUpdaterController?

    func start() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    func check() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "FinderPack"
            alert.informativeText = NSLocalizedString("Automatic updates are not configured for this build. Use Project and releases to check available downloads.", comment: "")
            alert.runModal()
            return
        }
        controller.checkForUpdates(nil)
    }

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // Sparkle invokes updater delegates on the main thread.
        MainActor.assumeIsolated {
            do {
                try SMAppService.agent(plistName: "FinderPackAgent.plist").unregister()
                UserDefaults.standard.set(true, forKey: "ReconnectHelperAfterUpdate")
            } catch {
                UserDefaults.standard.set(false, forKey: "ReconnectHelperAfterUpdate")
            }
        }
    }

    func restoreHelper() {
        guard UserDefaults.standard.bool(forKey: "ReconnectHelperAfterUpdate") else { return }
        do {
            try SMAppService.agent(plistName: "FinderPackAgent.plist").register()
            UserDefaults.standard.removeObject(forKey: "ReconnectHelperAfterUpdate")
        } catch {
            let alert = NSAlert()
            alert.messageText = "FinderPack"
            alert.informativeText = NSLocalizedString("Reconnect the background helper in FinderPack settings to finish the update.", comment: "")
            alert.runModal()
        }
    }
}
