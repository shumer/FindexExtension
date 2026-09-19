import Foundation
import FinderPackCore

@MainActor
final class ActionClient {
    private var connection: NSXPCConnection?
    private var timeout: Task<Void, Never>?
    private var completion: (@MainActor @Sendable (ActionReply) -> Void)?
    private var requestID: UUID?

    func perform(_ request: ActionRequest, completion: @escaping @MainActor @Sendable (ActionReply) -> Void) {
        guard connection == nil else {
            completion(ActionReply(requestID: request.id, succeeded: false, message: ProductText.value("busy")))
            return
        }
        do {
            let config = try ServiceConfiguration()
            let payload = try JSONEncoder().encode(request)
            _ = try ActionRequest.decode(payload)
            let connection = NSXPCConnection(machServiceName: config.service)
            connection.remoteObjectInterface = NSXPCInterface(with: DiagnosticProtocol.self)
            connection.setCodeSigningRequirement(config.agentRequirement)
            self.connection = connection
            self.completion = completion
            requestID = request.id
            let failure = ActionReply(requestID: request.id, succeeded: false,
                                      message: ProductText.value(request.action == .enableNotifications ? "notificationUncertain" : "uncertain"))
            connection.invalidationHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.finish(failure) }
            }
            connection.interruptionHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.finish(failure) }
            }
            connection.resume()
            timeout = Task { [weak self] in
                let seconds = request.action == .setupStatus ? 5 : [FileAction.moveTo, .undoMove, .pasteFiles, .pasteMove, .moveHere].contains(request.action)
                    ? 86_400 : ([FileAction.enableNotifications, .openIn, .requestFinderAutomation].contains(request.action) ? 300 : 15)
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                self?.finish(failure)
            }
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable [weak self] _ in
                Task { @MainActor in self?.finish(failure) }
            }
            guard let remote = proxy as? DiagnosticProtocol else { finish(failure); return }
            remote.perform(payload) { @Sendable [weak self] data in
                var result = failure
                if let data, data.count <= 1_048_576,
                   let decoded = try? JSONDecoder().decode(ActionReply.self, from: data),
                   decoded.version == 2, decoded.requestID == request.id {
                    result = decoded
                }
                let response = result
                Task { @MainActor in self?.finish(response) }
            }
        } catch {
            completion(ActionReply(requestID: request.id, succeeded: false,
                                   message: ProductText.value(request.action == .enableNotifications ? "notificationUncertain" : "failed")))
        }
    }

    private func finish(_ response: ActionReply) {
        guard requestID == response.requestID else { return }
        let callback = completion
        completion = nil
        requestID = nil
        timeout?.cancel()
        timeout = nil
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
        callback?(response)
    }
}
