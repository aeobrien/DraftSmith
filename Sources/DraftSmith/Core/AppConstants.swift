import Foundation

enum AppConstants {
    // MARK: - Annotation Keys
    static let dsUUIDAnnotationKey = "ds_uuid"
    static let dsUUIDFallbackPrefix = "[ds:"
    static let dsUUIDFallbackSuffix = "]"

    // MARK: - LanguageTool
    static let languageToolBaseURL = URL(string: "http://127.0.0.1:8081")!
    static let languageToolCheckPath = "/v2/check"
    static let languageToolLanguagesPath = "/v2/languages"
    static let languageToolLanguage = "en-GB"

    // MARK: - Token Budgets
    enum TokenBudget {
        static let system = 300
        static let guide = 200
        static let capsule = 500
        static let examples = 1500
        static let input = 1500
        static let output = 3900
        static let metadata = 100
        static let total = 8000
    }

    // MARK: - Service Manager
    static let healthCheckInterval: TimeInterval = 30
    static let maxHealthCheckRetries = 3
    static let lowRAMThreshold: UInt64 = 8 * 1024 * 1024 * 1024 // 8GB

    // MARK: - Style Memory
    static let capsuleMaxTokens = 500
    static let feedbackEventsPerCapsuleRegeneration = 10
    static let maxExamplesPerPrompt = 5
    static let minExamplesPerPrompt = 2

    // MARK: - LLM
    static let defaultVariantCount = 3
    static let maxVariantCount = 5
    static let maxDoubleCheckRetries = 2

    // MARK: - Audio
    static let audioSampleRate: Double = 16000
    static let audioChannels: Int = 1

    // MARK: - OpenAI (Problem Log Chat)
    static let openAIAPIKey = ProcessInfo.processInfo.environment["DRAFTSMITH_OPENAI_API_KEY"] ?? ""
    static let openAIModel = "gpt-5.2"
    static let openAIBaseURL = "https://api.openai.com/v1/chat/completions"

    // MARK: - App Info
    static let appName = "Draftsmith"
    static let appSupportDirectoryName = "Draftsmith"
}
