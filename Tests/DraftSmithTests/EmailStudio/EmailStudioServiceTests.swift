import XCTest
import SwiftData
@testable import DraftSmith

@MainActor
final class EmailStudioServiceTests: XCTestCase {

    // MARK: - Issue Context Insertion

    func testInsertIssueContext_includesMessage() {
        let container = TestHelpers.createTestModelContainer()
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let serviceManager = ServiceManager(capabilities: capabilities)
        let promptManager = PromptManagerService(modelContext: container.mainContext)
        let styleMemory = StyleMemoryManager(modelContext: container.mainContext)
        let pipeline = DoubleCheckPipeline(languageToolClient: LanguageToolClient())

        let service = EmailStudioService(
            serviceManager: serviceManager,
            promptManager: promptManager,
            styleMemoryManager: styleMemory,
            doubleCheckPipeline: pipeline
        )

        let issue = Issue(
            pageIndex: 2,
            selectionText: "their",
            message: "Possible confusion of 'their' and 'there'",
            category: "Confused Words",
            suggestions: ["there"],
            severity: .warning
        )

        let context = service.insertIssueContext(issue: issue)

        XCTAssertTrue(context.contains("Possible confusion of 'their' and 'there'"))
        XCTAssertTrue(context.contains("their"))
        XCTAssertTrue(context.contains("Confused Words"))
        XCTAssertTrue(context.contains("Page: 3"), "Page should be displayed as 1-indexed (pageIndex 2 -> Page 3)")
    }

    func testInsertIssueContext_includesFlaggedText() {
        let container = TestHelpers.createTestModelContainer()
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let serviceManager = ServiceManager(capabilities: capabilities)
        let promptManager = PromptManagerService(modelContext: container.mainContext)
        let styleMemory = StyleMemoryManager(modelContext: container.mainContext)
        let pipeline = DoubleCheckPipeline(languageToolClient: LanguageToolClient())

        let service = EmailStudioService(
            serviceManager: serviceManager,
            promptManager: promptManager,
            styleMemoryManager: styleMemory,
            doubleCheckPipeline: pipeline
        )

        let issue = Issue(
            pageIndex: 0,
            selectionText: "utilize",
            message: "Consider using 'use' instead of 'utilize'",
            severity: .info
        )

        let context = service.insertIssueContext(issue: issue)

        XCTAssertTrue(context.contains("utilize"))
        XCTAssertTrue(context.contains("Flagged text"))
    }

    func testInsertIssueContext_omitsCategoryWhenNil() {
        let container = TestHelpers.createTestModelContainer()
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let serviceManager = ServiceManager(capabilities: capabilities)
        let promptManager = PromptManagerService(modelContext: container.mainContext)
        let styleMemory = StyleMemoryManager(modelContext: container.mainContext)
        let pipeline = DoubleCheckPipeline(languageToolClient: LanguageToolClient())

        let service = EmailStudioService(
            serviceManager: serviceManager,
            promptManager: promptManager,
            styleMemoryManager: styleMemory,
            doubleCheckPipeline: pipeline
        )

        let issue = Issue(
            pageIndex: 0,
            selectionText: "word",
            message: "Some issue"
        )

        let context = service.insertIssueContext(issue: issue)

        XCTAssertFalse(context.contains("Category:"), "Category line should not appear when category is nil")
    }

    // MARK: - EmailGenerationRequest

    func testEmailGenerationRequest_defaultAxes() {
        let request = EmailGenerationRequest(goal: "Request feedback")

        XCTAssertEqual(request.axes, PreferenceAxes.default)
        XCTAssertEqual(request.goal, "Request feedback")
        XCTAssertTrue(request.recipientContext.isEmpty)
        XCTAssertTrue(request.keyFacts.isEmpty)
    }

    func testEmailGenerationRequest_customValues() {
        let axes = PreferenceAxes(directness: 0.8, brevity: 0.3, formality: 0.2, rewriteVsComment: 0.0)
        let request = EmailGenerationRequest(
            recipientContext: "Senior editor at publishing house",
            goal: "Discuss manuscript revisions",
            keyFacts: "Deadline is March 15",
            axes: axes
        )

        XCTAssertEqual(request.recipientContext, "Senior editor at publishing house")
        XCTAssertEqual(request.goal, "Discuss manuscript revisions")
        XCTAssertEqual(request.keyFacts, "Deadline is March 15")
        XCTAssertEqual(request.axes.directness, 0.8, accuracy: 0.01)
    }

    // MARK: - Service Initial State

    func testEmailStudioService_initialState() {
        let container = TestHelpers.createTestModelContainer()
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let serviceManager = ServiceManager(capabilities: capabilities)
        let promptManager = PromptManagerService(modelContext: container.mainContext)
        let styleMemory = StyleMemoryManager(modelContext: container.mainContext)
        let pipeline = DoubleCheckPipeline(languageToolClient: LanguageToolClient())

        let service = EmailStudioService(
            serviceManager: serviceManager,
            promptManager: promptManager,
            styleMemoryManager: styleMemory,
            doubleCheckPipeline: pipeline
        )

        XCTAssertFalse(service.isGenerating)
        XCTAssertTrue(service.subjectOptions.isEmpty)
        XCTAssertTrue(service.drafts.isEmpty)
    }
}
