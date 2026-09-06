import Foundation

@MainActor
final class CapsuleGenerator {
    private let serviceManager: ServiceManager
    private let promptManager: PromptManagerService
    private let styleMemoryManager: StyleMemoryManager
    private let parser = LLMResponseParser()
    private let tokenCounter = TokenCounter()

    init(
        serviceManager: ServiceManager,
        promptManager: PromptManagerService,
        styleMemoryManager: StyleMemoryManager
    ) {
        self.serviceManager = serviceManager
        self.promptManager = promptManager
        self.styleMemoryManager = styleMemoryManager
    }

    func generateCapsule() async throws -> StyleCapsule {
        await serviceManager.ensureReady(.llm)

        let examples = styleMemoryManager.fetchAllExamplePairs()
        let feedbackEvents = styleMemoryManager.fetchAllFeedbackEvents()

        let examplesText = examples.map { "Input: \($0.inputText)\nOutput: \($0.outputText)" }.joined(separator: "\n\n")
        let feedbackText = feedbackEvents.prefix(20).map { event in
            "Original: \(event.originalSuggestion)\nEdited: \(event.editedFinal)\nTags: \(event.editIntentTags.joined(separator: ", "))"
        }.joined(separator: "\n\n")

        let assembled = try promptManager.assemblePrompt(
            task: .styleCapsuleGeneration,
            placeholders: [
                "example_pairs": examplesText.isEmpty ? "(No examples yet)" : examplesText,
                "feedback_events": feedbackText.isEmpty ? "(No feedback yet)" : feedbackText
            ]
        )

        let llmOutput = try await serviceManager.llmService.generate(
            prompt: assembled.userPrompt,
            systemPrompt: assembled.systemPrompt
        )

        let response = try parser.parse(llmOutput, as: StyleCapsuleResponse.self)

        // Enforce 500-token limit
        var capsuleText = response.capsuleText
        if tokenCounter.countTokens(capsuleText) > AppConstants.capsuleMaxTokens {
            capsuleText = tokenCounter.trim(capsuleText, toFit: AppConstants.capsuleMaxTokens)
        }

        let capsule = StyleCapsule(
            capsuleText: capsuleText,
            keyTendencies: response.keyTendencies,
            tokenCount: tokenCounter.countTokens(capsuleText),
            isPendingApproval: true
        )

        return capsule
    }
}
