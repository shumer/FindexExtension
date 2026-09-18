import Foundation
import Darwin

@main
struct RejectedClient {
    static func main() {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let connection = NSXPCConnection(machServiceName: CommandLine.arguments[1])
        connection.remoteObjectInterface = NSXPCInterface(with: DiagnosticProtocol.self)
        connection.resume()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ @Sendable error in
            let failure = error as NSError
            print("Request rejected: \(failure.domain) code \(failure.code). Confirm signature rejection in the agent log.")
            exit(0)
        }) as? DiagnosticProtocol else { exit(2) }
        proxy.ping(Data()) { _ in
            print("Failure: an unrelated client reached the exported method.")
            exit(1)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            print("Inconclusive: request timed out.")
            exit(2)
        }
        withExtendedLifetime(connection) { RunLoop.current.run() }
    }
}
