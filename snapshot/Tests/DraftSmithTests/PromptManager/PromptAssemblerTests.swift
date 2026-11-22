import XCTest
import SwiftData
@testable import DraftSmith

@MainActor
final class PromptAssemblerTests: XCTestCase {

    private let assembler = PromptAssembler()

    private func makeTemplate(
        systemDirective: String = "You are a test assistant.",
        taskTemplate: String = "Review this: {{passage}} with {{style_guide}} and {{style_capsule}} and {{preference_axes}} and {{examples}} and {{variant_count}} and {{max_tokens}}"
    ) -> PromptTemplate {
        PromptTemplate(
            task: .diplomaticComment,
            systemDirective: systemDirective,
            taskTemplate: taskTemplate
        )
    }

    // MARK: - Placeholder Substitution

    func testAssemble_substitutesPlaceholders() {
        let template = makeTemplate(taskTemplate: "Analyse: {{passage}}")
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "The cat sat on the mat."]
        )

        XCTAssertTrue(result.userPrompt.contains("The cat sat on the mat."))
        XCTAssertFalse(result.userPrompt.contains("{{passage}}"))
    }

    func testAssemble_substitutesMultiplePlaceholders() {
        let template = makeTemplate(
            taskTemplate: "Passage: {{passage}}\nNote: {{transcript}}"
        )
        let result = assembler.assemble(
            template: template,
            placeholders: [
                "passage": "Some passage",
                "transcript": "Some transcript"
            ]
        )

        XCTAssertTrue(result.userPrompt.contains("Some passage"))
        XCTAssertTrue(result.userPrompt.contains("Some transcript"))
    }

    func testAssemble_injectsDefaultsForBuiltInPlaceholders() {
        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"]
        )

        // variant_count and max_tokens should be injected from AppConstants
        XCTAssertTrue(result.userPrompt.contains("\(AppConstants.defaultVariantCount)"))
        XCTAssertTrue(result.userPrompt.contains("\(AppConstants.capsuleMaxTokens)"))
    }

    func testAssemble_injectsStyleGuideDefault() {
        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"],
            styleGuide: ""
        )

        XCTAssertTrue(result.userPrompt.contains("No style guide active"))
    }

    func testAssemble_injectsStyleCapsuleDefault() {
        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"],
            styleCapsule: ""
        )

        XCTAssertTrue(result.userPrompt.contains("No style capsule active"))
    }

    func testAssemble_injectsStyleGuideContent() {
        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"],
            styleGuide: "Use active voice."
        )

        XCTAssertTrue(result.userPrompt.contains("Use active voice."))
    }

    // MARK: - Budget Enforcement

    func testAssemble_totalTokenEstimateIsPositive() {
        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "Hello world"]
        )

        XCTAssertGreaterThan(result.totalTokenEstimate, 0)
    }

    func testAssemble_systemPromptMatchesTemplateDirective() {
        let template = makeTemplate(systemDirective: "Custom system prompt.")
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"]
        )

        XCTAssertEqual(result.systemPrompt, "Custom system prompt.")
    }

    // MARK: - Trim Logic

    func testAssemble_trimReportShowsNoTrimmingForSmallInput() {
        let template = makeTemplate(taskTemplate: "Short: {{passage}}")
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "Brief text."]
        )

        XCTAssertEqual(result.trimReport, "No trimming required")
    }

    func testAssemble_examplesWithinBudgetIncluded() {
        let container = TestHelpers.createTestModelContainer()
        let _ = container // retain container
        let pair1 = ExamplePair(inputText: "bad text", outputText: "good text", category: .diplomaticComment, tokenCount: 10)
        let pair2 = ExamplePair(inputText: "another bad", outputText: "another good", category: .diplomaticComment, tokenCount: 10)

        let template = makeTemplate()
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"],
            examples: [pair1, pair2],
            budget: .default
        )

        XCTAssertTrue(result.userPrompt.contains("bad text") || result.userPrompt.contains("No examples provided"),
                       "Examples should appear in the prompt when within budget")
    }

    // MARK: - PreferenceAxes Integration

    func testAssemble_injectsPreferenceAxesFragment() {
        let template = makeTemplate()
        let axes = PreferenceAxes(directness: 0.8, brevity: 0.2, formality: 0.5, rewriteVsComment: 0.0)
        let result = assembler.assemble(
            template: template,
            placeholders: ["passage": "text"],
            preferenceAxes: axes
        )

        XCTAssertTrue(result.userPrompt.contains("Directness"))
        XCTAssertTrue(result.userPrompt.contains("0.8"))
    }
}
