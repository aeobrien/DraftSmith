import Foundation

actor MockLanguageToolService: ManagedServiceProtocol {
    let kind: ServiceKind = .languageTool
    private(set) var state: ServiceState = .ready

    var mockResponse: LanguageToolResponse?

    func start() async throws {
        state = .ready
    }

    func stop() async {
        state = .idle
    }

    func healthCheck() async -> Bool {
        return true
    }

    func check(text: String, enabledRules: [String] = [], disabledRules: [String] = [], enabledCategories: [String] = [], disabledCategories: [String] = [], level: String = "default") async throws -> LanguageToolResponse {
        if let mock = mockResponse {
            return mock
        }
        return LanguageToolResponse(software: nil, language: nil, matches: [])
    }
}
