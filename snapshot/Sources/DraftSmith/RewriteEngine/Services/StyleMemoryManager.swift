import Foundation
import SwiftData

@Observable
@MainActor
final class StyleMemoryManager {
    private let modelContext: ModelContext
    private let feedbackAnalyzer = FeedbackAnalyzer()
    private let tokenCounter = TokenCounter()

    private(set) var feedbackCount: Int = 0
    var activeCapsuleText: String {
        activeCapsule?.capsuleText ?? ""
    }

    private var activeCapsule: StyleCapsule?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Note: loadActiveCapsule() and countFeedbackEvents() deferred to
        // loadInitialState() to avoid SwiftData runtime crash (SIGTRAP) when
        // fetching models with computed properties using JSON-decoded arrays.
    }

    /// Call after init to load persisted state. Safe to call from non-init contexts.
    func loadInitialState() {
        loadActiveCapsule()
        countFeedbackEvents()
    }

    // MARK: - Example Pairs

    func addExamplePair(input: String, output: String, category: PromptTask) {
        let tokenCount = tokenCounter.countTokens(input) + tokenCounter.countTokens(output)
        let pair = ExamplePair(
            inputText: input,
            outputText: output,
            category: category,
            tokenCount: tokenCount
        )
        modelContext.insert(pair)
        try? modelContext.save()
    }

    func selectExamples(for task: PromptTask, budget: Int = AppConstants.TokenBudget.examples) -> [ExamplePair] {
        let descriptor = FetchDescriptor<ExamplePair>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let allPairs = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.category == task.rawValue }

        // Select within budget, most recent first
        var selected: [ExamplePair] = []
        var usedTokens = 0

        for pair in allPairs {
            if selected.count >= AppConstants.maxExamplesPerPrompt { break }
            if usedTokens + pair.tokenCount > budget { break }
            selected.append(pair)
            usedTokens += pair.tokenCount
        }

        return selected
    }

    func deleteExamplePair(_ pair: ExamplePair) {
        modelContext.delete(pair)
        try? modelContext.save()
    }

    func fetchAllExamplePairs() -> [ExamplePair] {
        let descriptor = FetchDescriptor<ExamplePair>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Feedback

    func recordFeedback(originalSuggestion: String, editedFinal: String) {
        let analysis = feedbackAnalyzer.analyze(original: originalSuggestion, edited: editedFinal)

        let event = FeedbackEvent(
            originalSuggestion: originalSuggestion,
            editedFinal: editedFinal,
            wordLevelDiff: try? JSONEncoder().encode(analysis.diff),
            lengthChangeRatio: analysis.lengthChangeRatio,
            editDistance: analysis.editDistance,
            editIntentTags: analysis.intentTags
        )
        modelContext.insert(event)
        try? modelContext.save()

        feedbackCount += 1
    }

    var shouldRegenerateCapsule: Bool {
        feedbackCount > 0 && feedbackCount % AppConstants.feedbackEventsPerCapsuleRegeneration == 0
    }

    // MARK: - Style Capsule

    func approveCapsule(_ capsule: StyleCapsule) {
        // Deactivate current
        if let current = activeCapsule {
            current.isActive = false
        }
        capsule.isActive = true
        capsule.isPendingApproval = false
        capsule.activatedAt = Date()
        activeCapsule = capsule
        try? modelContext.save()
    }

    func dismissCapsule(_ capsule: StyleCapsule) {
        capsule.isPendingApproval = false
        try? modelContext.save()
    }

    func resetCapsule() {
        if let current = activeCapsule {
            current.isActive = false
        }
        activeCapsule = nil
        try? modelContext.save()
    }

    func pendingCapsule() -> StyleCapsule? {
        let descriptor = FetchDescriptor<StyleCapsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.first { $0.isPendingApproval }
    }

    func fetchAllFeedbackEvents() -> [FeedbackEvent] {
        let descriptor = FetchDescriptor<FeedbackEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func loadActiveCapsule() {
        let descriptor = FetchDescriptor<StyleCapsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        activeCapsule = (try? modelContext.fetch(descriptor))?.first { $0.isActive }
    }

    private func countFeedbackEvents() {
        let descriptor = FetchDescriptor<FeedbackEvent>()
        feedbackCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
