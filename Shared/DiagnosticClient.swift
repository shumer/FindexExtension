import Foundation
import FinderPackCore

@MainActor
final class DiagnosticClient {
    private var connection: NSXPCConnection?
    private var timeout: Task<Void, Never>?
    private var completion: (@MainActor @Sendable (String) -> Void)?
    private var requestID: UUID?

    func ping(selectedURLs: [URL] = [], targetedURL: URL? = nil,
              completion: @escaping @MainActor @Sendable (String) -> Void) {
        guard connection == nil else {
            completion("A connection check is already running.")
            return
        }
        do {
            let configuration = try ServiceConfiguration()
            let request = DiagnosticRequest(selectedURLs: selectedURLs, targetedURL: targetedURL)
            let payload = try JSONEncoder().encode(request)
            _ = try DiagnosticRequest.decode(payload)
            try GroupProbe.prepare(request.id)
            let connection = NSXPCConnection(machServiceName: configuration.service)
            connection.remoteObjectInterface = NSXPCInterface(with: DiagnosticProtocol.self)
            connection.setCodeSigningRequirement(configuration.agentRequirement)
            self.connection = connection
            self.completion = completion
            self.requestID = request.id
            connection.invalidationHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.finish("Agent connection closed.", id: request.id) }
            }
            connection.interruptionHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.finish("Agent connection interrupted.", id: request.id) }
            }
            connection.resume()
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                self?.finish("Agent did not respond. Check background-service approval.", id: request.id)
            }
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable [weak self] _ in
                Task { @MainActor in self?.finish("Cannot reach the signed agent. Check registration and signing.", id: request.id) }
            }
            guard let remote = proxy as? DiagnosticProtocol else {
                finish("Agent protocol is unavailable.", id: request.id)
                return
            }
            remote.ping(payload) { [weak self] data in
                let valid = data.flatMap { try? JSONDecoder().decode(DiagnosticReply.self, from: $0) }
                let message = valid?.requestID == request.id && valid?.version == 1 && valid?.accepted == true && GroupProbe.verify(request.id)
                    ? "Connection and shared container verified. The agent accepted the diagnostic request."
                    : "Agent returned an invalid diagnostic response."
                Task { @MainActor in self?.finish(message, id: request.id) }
            }
        } catch {
            completion(error.localizedDescription)
        }
    }

    private func finish(_ message: String, id: UUID) {
        guard requestID == id else { return }
        let callback = completion
        completion = nil
        requestID = nil
        GroupProbe.clean(id)
        timeout?.cancel()
        timeout = nil
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
        callback?(message)
    }
}
