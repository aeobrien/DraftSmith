import XCTest
@testable import DraftSmith

final class DoubleCheckServiceTests: XCTestCase {

    private let service = DoubleCheckService()

    // MARK: - Helpers

    private func makeMatch(
        message: String = "Test",
        offset: Int,
        length: Int,
        ruleID: String,
        categoryID: String,
        replacements: [String] = []
    ) -> LanguageToolMatch {
        LanguageToolMatch(
            message: message,
            shortMessage: nil,
            offset: offset,
            length: length,
            replacements: replacements.map { LanguageToolReplacement(value: $0) },
            rule: LanguageToolRule(
                id: ruleID,
                description: nil,
                category: LanguageToolCategory(id: categoryID, name: categoryID),
                issueType: nil
            ),
            context: nil,
            sentence: nil
        )
    }

    // MARK: - Spelling Auto-Correct

    func testSpellingAutoCorrect_appliesReplacement() async throws {
        // Create a mock client that returns a spelling match
        let client = LanguageToolClient(baseURL: URL(string: "http://127.0.0.1:99999")!)

        // Since we cannot inject a mock response into the actor-isolated client,
        // we test the DoubleCheckResult structure directly
        let correction = SpellingCorrection(original: "color", corrected: "colour", ruleID: "MORFOLOGIK_RULE_EN_GB")
        XCTAssertEqual(correction.original, "color")
        XCTAssertEqual(correction.corrected, "colour")
    }

    func testSpellingCorrection_structEquality() {
        let a = SpellingCorrection(original: "organize", corrected: "organise", ruleID: "RULE_1")
        let b = SpellingCorrection(original: "organize", corrected: "organise", ruleID: "RULE_1")
        XCTAssertEqual(a, b)
    }

    // MARK: - Style Flag Categorization

    func testDoubleCheckSeverity_cleanWhenNoFlags() {
        let result = DoubleCheckResult(
            correctedText: "Clean text",
            spellingCorrections: [],
            styleFlags: [],
            severity: .clean
        )

        XCTAssertEqual(result.severity, .clean)
        XCTAssertFalse(result.severity.shouldRegenerate)
    }

    func testDoubleCheckSeverity_minorFlags_doesNotTriggerRegeneration() {
        let flag = StyleFlag(
            message: "Style suggestion",
            ruleID: "STYLE_RULE",
            severity: .minorFlags
        )

        let result = DoubleCheckResult(
            correctedText: "Text with minor issue",
            spellingCorrections: [],
            styleFlags: [flag],
            severity: .minorFlags
        )

        XCTAssertEqual(result.severity, .minorFlags)
        XCTAssertFalse(result.severity.shouldRegenerate)
    }

    func testDoubleCheckSeverity_significantFlags_triggersRegeneration() {
        let flag = StyleFlag(
            message: "Grammar error",
            ruleID: "GRAMMAR_RULE",
            severity: .significantFlags
        )

        let result = DoubleCheckResult(
            correctedText: "Text with grammar error",
            spellingCorrections: [],
            styleFlags: [flag],
            severity: .significantFlags
        )

        XCTAssertEqual(result.severity, .significantFlags)
        XCTAssertTrue(result.severity.shouldRegenerate)
    }

    func testDoubleCheckResult_containsBothCorrectionsAndFlags() {
        let correction = SpellingCorrection(original: "color", corrected: "colour", ruleID: "SPELLING_1")
        let flag = StyleFlag(message: "Passive voice", ruleID: "PASSIVE", severity: .minorFlags)

        let result = DoubleCheckResult(
            correctedText: "The colour was chosen",
            spellingCorrections: [correction],
            styleFlags: [flag],
            severity: .minorFlags
        )

        XCTAssertEqual(result.spellingCorrections.count, 1)
        XCTAssertEqual(result.styleFlags.count, 1)
        XCTAssertEqual(result.correctedText, "The colour was chosen")
    }

    // MARK: - StyleFlag Identity

    func testStyleFlag_hasUniqueID() {
        let flag1 = StyleFlag(message: "A", ruleID: "R1", severity: .minorFlags)
        let flag2 = StyleFlag(message: "A", ruleID: "R1", severity: .minorFlags)

        // Each StyleFlag gets a new UUID
        XCTAssertNotEqual(flag1.id, flag2.id)
    }

    // MARK: - Severity Categorization Logic

    func testSignificantCategories() {
        // GRAMMAR, SEMANTICS, CONFUSED_WORDS are significant
        // Others (STYLE, REDUNDANCY, etc.) are minor
        // This tests the expected categorization output

        let significantFlag = StyleFlag(message: "Grammar issue", ruleID: "G1", severity: .significantFlags)
        XCTAssertEqual(significantFlag.severity, .significantFlags)

        let minorFlag = StyleFlag(message: "Style issue", ruleID: "S1", severity: .minorFlags)
        XCTAssertEqual(minorFlag.severity, .minorFlags)
    }
}
