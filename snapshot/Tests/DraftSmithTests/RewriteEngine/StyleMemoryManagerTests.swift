import XCTest
import SwiftData
@testable import DraftSmith

@MainActor
final class StyleMemoryManagerTests: XCTestCase {

    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var manager: StyleMemoryManager!

    override func setUp() {
        super.setUp()
        container = TestHelpers.createTestModelContainer()
        modelContext = container.mainContext
        manager = StyleMemoryManager(modelContext: modelContext)
    }

    // MARK: - Example Selection Within Budget

    func testSelectExamples_returnsEmptyWhenNoneExist() {
        let selected = manager.selectExamples(for: .diplomaticComment)
        XCTAssertTrue(selected.isEmpty)
    }

    func testSelectExamples_returnsExamplesForMatchingTask() {
        manager.addExamplePair(
            input: "Bad text",
            output: "Good text",
            category: .diplomaticComment
        )
        manager.addExamplePair(
            input: "Wrong",
            output: "Right",
            category: .rewriteSuggestion
        )

        let commentExamples = manager.selectExamples(for: .diplomaticComment)
        XCTAssertEqual(commentExamples.count, 1)
        XCTAssertEqual(commentExamples.first?.inputText, "Bad text")

        let rewriteExamples = manager.selectExamples(for: .rewriteSuggestion)
        XCTAssertEqual(rewriteExamples.count, 1)
        XCTAssertEqual(rewriteExamples.first?.inputText, "Wrong")
    }

    func testSelectExamples_respectsBudget() {
        // Add many examples with large token counts
        for i in 0..<20 {
            let longInput = Array(repeating: "word\(i)", count: 50).joined(separator: " ")
            let longOutput = Array(repeating: "fixed\(i)", count: 50).joined(separator: " ")
            manager.addExamplePair(
                input: longInput,
                output: longOutput,
                category: .diplomaticComment
            )
        }

        // With a small budget, not all examples should be selected
        let selected = manager.selectExamples(for: .diplomaticComment, budget: 50)
        XCTAssertLessThan(selected.count, 20, "Should not return all examples when budget is small")
    }

    func testSelectExamples_respectsMaxCount() {
        // Add more than maxExamplesPerPrompt
        for i in 0..<10 {
            manager.addExamplePair(
                input: "in\(i)",
                output: "out\(i)",
                category: .diplomaticComment
            )
        }

        let selected = manager.selectExamples(for: .diplomaticComment, budget: 100_000)
        XCTAssertLessThanOrEqual(selected.count, AppConstants.maxExamplesPerPrompt)
    }

    // MARK: - Feedback Recording

    func testRecordFeedback_incrementsFeedbackCount() {
        XCTAssertEqual(manager.feedbackCount, 0)

        manager.recordFeedback(
            originalSuggestion: "Perhaps consider revising this.",
            editedFinal: "Revise this."
        )

        XCTAssertEqual(manager.feedbackCount, 1)
    }

    func testRecordFeedback_persistsFeedbackEvent() {
        manager.recordFeedback(
            originalSuggestion: "Original suggestion text",
            editedFinal: "Edited final text"
        )

        let events = manager.fetchAllFeedbackEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.originalSuggestion, "Original suggestion text")
        XCTAssertEqual(events.first?.editedFinal, "Edited final text")
    }

    func testRecordFeedback_computesAnalysisFields() {
        manager.recordFeedback(
            originalSuggestion: "Perhaps this might need some revision for clarity.",
            editedFinal: "Revise for clarity."
        )

        let events = manager.fetchAllFeedbackEvents()
        let event = events.first!

        XCTAssertGreaterThan(event.editDistance, 0)
        XCTAssertLessThan(event.lengthChangeRatio, 1.0, "Shortened text should have ratio < 1")
    }

    // MARK: - Capsule Regeneration Trigger

    func testShouldRegenerateCapsule_falseInitially() {
        XCTAssertFalse(manager.shouldRegenerateCapsule)
    }

    func testShouldRegenerateCapsule_trueAfterThresholdEvents() {
        let threshold = AppConstants.feedbackEventsPerCapsuleRegeneration

        for i in 0..<threshold {
            manager.recordFeedback(
                originalSuggestion: "Suggestion \(i)",
                editedFinal: "Edited \(i)"
            )
        }

        XCTAssertEqual(manager.feedbackCount, threshold)
        XCTAssertTrue(manager.shouldRegenerateCapsule,
                       "Should trigger regeneration after \(threshold) feedback events")
    }

    // MARK: - Style Capsule Management

    func testActiveCapsuleText_emptyWhenNoCapsule() {
        XCTAssertEqual(manager.activeCapsuleText, "")
    }

    func testApproveCapsule_setsActive() {
        let capsule = StyleCapsule(
            capsuleText: "This editor prefers British English and concise phrasing.",
            keyTendencies: ["brevity", "British spelling"],
            tokenCount: 15,
            isPendingApproval: true
        )
        modelContext.insert(capsule)

        manager.approveCapsule(capsule)

        XCTAssertTrue(capsule.isActive)
        XCTAssertFalse(capsule.isPendingApproval)
        XCTAssertNotNil(capsule.activatedAt)
        XCTAssertEqual(manager.activeCapsuleText, capsule.capsuleText)
    }

    func testDismissCapsule_clearsPendingApproval() {
        let capsule = StyleCapsule(
            capsuleText: "Some capsule",
            isPendingApproval: true
        )
        modelContext.insert(capsule)

        manager.dismissCapsule(capsule)

        XCTAssertFalse(capsule.isPendingApproval)
        XCTAssertFalse(capsule.isActive)
    }

    func testResetCapsule_deactivatesCurrent() {
        let capsule = StyleCapsule(
            capsuleText: "Active capsule",
            isActive: true
        )
        modelContext.insert(capsule)

        // Need to approve first so manager tracks it
        manager.approveCapsule(capsule)
        XCTAssertEqual(manager.activeCapsuleText, "Active capsule")

        manager.resetCapsule()
        XCTAssertEqual(manager.activeCapsuleText, "")
    }

    // MARK: - Example Pair Deletion

    func testDeleteExamplePair_removesFromStore() {
        manager.addExamplePair(input: "in", output: "out", category: .diplomaticComment)

        let allPairs = manager.fetchAllExamplePairs()
        XCTAssertEqual(allPairs.count, 1)

        manager.deleteExamplePair(allPairs.first!)

        let remaining = manager.fetchAllExamplePairs()
        XCTAssertEqual(remaining.count, 0)
    }
}
