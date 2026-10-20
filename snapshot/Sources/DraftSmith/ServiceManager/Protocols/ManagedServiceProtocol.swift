import Foundation

protocol ManagedServiceProtocol: Actor {
    var kind: ServiceKind { get }
    var state: ServiceState { get }

    func start() async throws
    func stop() async
    func healthCheck() async -> Bool
}
