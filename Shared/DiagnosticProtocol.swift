import Foundation

@objc protocol DiagnosticProtocol {
    func perform(_ payload: Data, reply: @escaping @Sendable (Data?) -> Void)
    func ping(_ payload: Data, reply: @escaping @Sendable (Data?) -> Void)
}
