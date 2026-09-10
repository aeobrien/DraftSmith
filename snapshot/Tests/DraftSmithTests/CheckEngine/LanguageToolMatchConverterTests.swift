import XCTest
@testable import DraftSmith

final class LanguageToolMatchConverterTests: XCTestCase {

    // MARK: - Helpers

    private func makeMatch(
        message: String = "Test message",
        offset: Int = 0,
        length: Int = 5,
        ruleID: String = "TEST_RULE",
        categoryID: String = "TYPOS",
        categoryName: String = "Possible Typo",
        replacements: [String] = ["replacement"]
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
                category: LanguageToolCategory(id: categoryID, name: categoryName),
                issueType: nil
            ),
            context: nil,
            sentence: nil
        )
    }

    // MARK: - Basic Conversion

    func testConvert_producesIssueWithCorrectFields() {
        let converter = LanguageToolMatchConverter()
        let match = makeMatch(message: "Spelling error", offset: 0, length: 5, replacements: ["their"])
        let text = "thier example text"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 1, documentURL: "/doc.pdf")

        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.selectionText, "thier")
        XCTAssertEqual(issue?.message, "Spelling error")
        XCTAssertEqual(issue?.pageIndex, 1)
        XCTAssertEqual(issue?.documentURL, "/doc.pdf")
        XCTAssertEqual(issue?.suggestionsList, ["their"])
    }

    // MARK: - Dictionary Filtering

    func testConvert_skipsWordInCustomDictionary() {
        let converter = LanguageToolMatchConverter(
            customDictionary: ["thier"],
            terminologyPreferences: [],
            severityOverrides: [:]
        )

        let match = makeMatch(offset: 0, length: 5)
        let text = "thier example text"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertNil(issue, "Words in the custom dictionary should be skipped")
    }

    func testConvert_customDictionaryIsCaseInsensitive() {
        let converter = LanguageToolMatchConverter(
            customDictionary: ["THIER"],
            terminologyPreferences: [],
            severityOverrides: [:]
        )

        let match = makeMatch(offset: 0, length: 5)
        let text = "thier example text"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertNil(issue, "Custom dictionary lookup should be case-insensitive")
    }

    // MARK: - Severity Override

    func testConvert_appliesSeverityOverride() {
        let converter = LanguageToolMatchConverter(
            customDictionary: [],
            terminologyPreferences: [],
            severityOverrides: ["STYLE_RULE": .warning]
        )

        let match = makeMatch(
            offset: 0, length: 4,
            ruleID: "STYLE_RULE",
            categoryID: "STYLE",
            categoryName: "Style"
        )
        let text = "some text here"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.issueSeverity, .warning,
                       "Severity override should take precedence over default")
    }

    func testConvert_defaultSeverity_warningForTypos() {
        let converter = LanguageToolMatchConverter()

        let match = makeMatch(categoryID: "TYPOS", categoryName: "Possible Typo")
        let text = "erors in text here"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertEqual(issue?.issueSeverity, .warning)
    }

    func testConvert_defaultSeverity_warningForGrammar() {
        let converter = LanguageToolMatchConverter()

        let match = makeMatch(categoryID: "GRAMMAR", categoryName: "Grammar")
        let text = "erors in text here"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertEqual(issue?.issueSeverity, .warning)
    }

    func testConvert_defaultSeverity_infoForStyleCategory() {
        let converter = LanguageToolMatchConverter()

        let match = makeMatch(categoryID: "STYLE", categoryName: "Style")
        let text = "erors in text here"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertEqual(issue?.issueSeverity, .info)
    }

    // MARK: - Terminology

    func testConvert_terminologyPassedThrough() {
        let terminology = [
            TerminologyEntry(preferred: "analyse", rejected: "analyze"),
            TerminologyEntry(preferred: "colour", rejected: "color")
        ]
        let converter = LanguageToolMatchConverter(
            customDictionary: [],
            terminologyPreferences: terminology,
            severityOverrides: [:]
        )

        // Terminology is stored but not directly filtered in convert;
        // it is used by the broader system. Verify converter initialises correctly.
        XCTAssertEqual(converter.terminologyPreferences.count, 2)
        XCTAssertEqual(converter.terminologyPreferences[0].preferred, "analyse")
    }

    // MARK: - ConvertAll

    func testConvertAll_processesMultipleMatches() {
        let converter = LanguageToolMatchConverter()

        let response = LanguageToolResponse(
            software: nil,
            language: nil,
            matches: [
                makeMatch(message: "Error 1", offset: 0, length: 4, ruleID: "R1"),
                makeMatch(message: "Error 2", offset: 10, length: 3, ruleID: "R2")
            ]
        )

        let text = "test some more text here"
        let issues = converter.convertAll(response: response, selectionText: text, pageIndex: 0, documentURL: nil)

        XCTAssertEqual(issues.count, 2)
    }

    func testConvertAll_filtersOutCustomDictionaryWords() {
        let converter = LanguageToolMatchConverter(
            customDictionary: ["test"],
            terminologyPreferences: [],
            severityOverrides: [:]
        )

        let response = LanguageToolResponse(
            software: nil,
            language: nil,
            matches: [
                makeMatch(message: "Error 1", offset: 0, length: 4, ruleID: "R1"),
                makeMatch(message: "Error 2", offset: 10, length: 3, ruleID: "R2")
            ]
        )

        let text = "test some more text here"
        let issues = converter.convertAll(response: response, selectionText: text, pageIndex: 0, documentURL: nil)

        // "test" at offset 0 should be filtered out
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].message, "Error 2")
    }

    // MARK: - Out-of-Range Match

    func testConvert_returnsNilForOutOfRangeMatch() {
        let converter = LanguageToolMatchConverter()

        let match = makeMatch(offset: 100, length: 10)
        let text = "short"

        let issue = converter.convert(match: match, selectionText: text, pageIndex: 0, documentURL: nil)
        XCTAssertNil(issue, "Match beyond text length should return nil")
    }
}
