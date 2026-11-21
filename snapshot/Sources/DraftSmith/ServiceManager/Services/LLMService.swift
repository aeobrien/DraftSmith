import Foundation
import MLXLLM
import MLXLMCommon

actor LLMService: ManagedServiceProtocol {
    let kind: ServiceKind = .llm
    private(set) var state: ServiceState = .idle

    private var modelContainer: ModelContainer?
    private let modelConfiguration: ModelConfiguration

    init() {
        self.modelConfiguration = SystemCapabilities.current.recommendedModelConfig().modelConfiguration
    }

    func start() async throws {
        guard state.isIdle || state == .error("") || !state.isReady else { return }
        state = .loading(progress: 0)

        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { progress in
                Task { @Sendable [weak self] in
                    await self?.updateProgress(progress.fractionCompleted)
                }
            }
            self.modelContainer = container
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw DraftSmithError.llmLoadFailed(error.localizedDescription)
        }
    }

    func stop() async {
        state = .unloading
        modelContainer = nil
        state = .idle
    }

    func healthCheck() async -> Bool {
        return modelContainer != nil && state.isReady
    }

    func generate(prompt: String, systemPrompt: String = "", maxTokens: Int = AppConstants.TokenBudget.output) async throws -> String {
        guard let container = modelContainer, state.isReady else {
            throw DraftSmithError.llmModelNotLoaded
        }

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(
                input: .init(messages: [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ])
            )
            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: 0.7, topP: 0.9),
                context: context
            ) { tokens in
                tokens.count >= maxTokens ? .stop : .more
            }
        }

        return result.output
    }

    // MARK: - Private

    private func updateProgress(_ progress: Double) {
        state = .loading(progress: progress)
    }
}
