import XCTest
@testable import DraftSmith

final class LLMResponseParserTests: XCTestCase {

    private let parser = LLMResponseParser()

    // MARK: - Test Model

    private struct SimpleResponse: Codable, Equatable {
        let message: String
        let count: Int
    }

    // MARK: - Clean JSON

    func testParse_cleanJSON() throws {
        let json = """
        {"message": "hello", "count": 42}
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "hello")
        XCTAssertEqual(result.count, 42)
    }

    func testParse_cleanJSON_withWhitespace() throws {
        let json = """

          { "message": "spaced", "count": 1 }

        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "spaced")
    }

    // MARK: - Markdown-Fenced JSON

    func testParse_markdownFencedJSON() throws {
        let json = """
        ```json
        {"message": "fenced", "count": 7}
        ```
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "fenced")
        XCTAssertEqual(result.count, 7)
    }

    func testParse_markdownFenced_withoutLanguageTag() throws {
        let json = """
        ```
        {"message": "no-lang", "count": 3}
        ```
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "no-lang")
    }

    // MARK: - JSON with Preamble

    func testParse_jsonWithPreamble() throws {
        let json = """
        Sure! Here is the JSON response:

        {"message": "preamble", "count": 99}
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "preamble")
        XCTAssertEqual(result.count, 99)
    }

    func testParse_jsonWithPreambleAndTrailing() throws {
        let json = """
        Here you go:
        ```json
        {"message": "both", "count": 5}
        ```
        Let me know if you need anything else!
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "both")
    }

    // MARK: - Trailing Comma Cleanup

    func testParse_trailingComma() throws {
        let json = """
        {"message": "comma", "count": 1,}
        """

        let result = try parser.parse(json, as: SimpleResponse.self)
        XCTAssertEqual(result.message, "comma")
    }

    // MARK: - Malformed JSON

    func testParse_malformedJSON_throws() {
        let json = "This is not JSON at all."

        XCTAssertThrowsError(try parser.parse(json, as: SimpleResponse.self))
    }

    func testParse_incompleteJSON_throws() {
        let json = """
        {"message": "incomplete"
        """

        XCTAssertThrowsError(try parser.parse(json, as: SimpleResponse.self))
    }

    // MARK: - extractJSON

    func testExtractJSON_findsFirstAndLastBraces() {
        let text = "Some text { \"key\": \"value\" } more text"
        let result = parser.extractJSON(from: text)
        XCTAssertEqual(result, "{ \"key\": \"value\" }")
    }

    func testExtractJSON_removesMarkdownFences() {
        let text = "```json\n{\"a\": 1}\n```"
        let result = parser.extractJSON(from: text)
        XCTAssertEqual(result, "{\"a\": 1}")
    }

    // MARK: - Complex Types

    func testParse_commentGenerationResponse() throws {
        let json = """
        {
            "variants": [
                {
                    "id": "v1",
                    "label": "Diplomatic",
                    "axes": {"directness": 0.3, "brevity": 0.5, "formality": 0.7, "rewrite_vs_comment": 0.0},
                    "text": "Consider revising this passage for clarity."
                }
            ],
            "notes_for_user": "One variant provided."
        }
        """

        let result = try parser.parse(json, as: CommentGenerationResponse.self)
        XCTAssertEqual(result.variants.count, 1)
        XCTAssertEqual(result.variants[0].id, "v1")
        XCTAssertEqual(result.variants[0].text, "Consider revising this passage for clarity.")
        XCTAssertEqual(result.notesForUser, "One variant provided.")
    }

    func testParse_emailDraftResponse() throws {
        let json = """
        {
            "subject_options": ["Meeting Follow-up", "Re: Project Update"],
            "drafts": [
                {
                    "id": "e1",
                    "label": "Formal",
                    "axes": {"directness": 0.5, "brevity": 0.5, "formality": 0.2, "rewrite_vs_comment": 0.0},
                    "body": "Dear colleague, I am writing to follow up."
                }
            ]
        }
        """

        let result = try parser.parse(json, as: EmailDraftResponse.self)
        XCTAssertEqual(result.subjectOptions.count, 2)
        XCTAssertEqual(result.drafts.count, 1)
        XCTAssertEqual(result.drafts[0].body, "Dear colleague, I am writing to follow up.")
    }
}
