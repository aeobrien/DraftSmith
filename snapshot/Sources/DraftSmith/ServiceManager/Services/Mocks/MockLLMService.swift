import Foundation

actor MockLLMService: ManagedServiceProtocol {
    let kind: ServiceKind = .llm
    private(set) var state: ServiceState = .ready

    var mockGenerationResult: String = "{\"variants\": []}"

    func start() async throws {
        state = .ready
    }

    func stop() async {
        state = .idle
    }

    func healthCheck() async -> Bool {
        return true
    }

    func generate(prompt: String, systemPrompt: String = "", maxTokens: Int = 3900) async throws -> String {
        return mockGenerationResult
    }
}
