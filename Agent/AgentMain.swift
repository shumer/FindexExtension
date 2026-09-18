import AppKit
import Foundation
import FinderPackCore
import OSLog

final class DiagnosticService: NSObject, DiagnosticProtocol {
    func perform(_ payload: Data, reply: @escaping @Sendable (Data?) -> Void) {
        guard let request = try? ActionRequest.decode(payload) else { reply(nil); return }
        Task {
            let result = await ActionExecutor.shared.perform(request)
            reply(try? JSONEncoder().encode(result))
        }
    }

    func ping(_ payload: Data, reply: @escaping @Sendable (Data?) -> Void) {
        guard let request = try? DiagnosticRequest.decode(payload) else {
            reply(nil)
            return
        }
        do {
            try GroupProbe.respond(request.id)
            reply(try JSONEncoder().encode(DiagnosticReply(requestID: request.id, accepted: true)))
        } catch {
            reply(try? JSONEncoder().encode(DiagnosticReply(requestID: request.id, accepted: false)))
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: DiagnosticProtocol.self)
        connection.exportedObject = DiagnosticService()
        connection.resume()
        return true
    }
}

@main
struct AgentMain {
    @MainActor static func main() {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinderPackAgent", category: "Lifecycle")
        do {
            let configuration = try ServiceConfiguration()
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            let delegate = ListenerDelegate()
            let listener = NSXPCListener(machServiceName: configuration.service)
            listener.setConnectionCodeSigningRequirement(configuration.clientRequirement)
            listener.delegate = delegate
            listener.resume()
            logger.info("Diagnostic agent started.")
            withExtendedLifetime((listener, delegate)) { application.run() }
        } catch {
            logger.error("Agent configuration is invalid; refusing to start.")
        }
    }
}
