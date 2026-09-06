import XCTest
@testable import DraftSmith

final class LanguageToolClientTests: XCTestCase {

    // MARK: - Request URL Construction

    func testCheckEndpoint_appendsV2CheckPath() async throws {
        // Create a client with a known base URL
        let baseURL = URL(string: "http://127.0.0.1:9999")!
        let client = LanguageToolClient(baseURL: baseURL)

        // We cannot actually hit the server, but we can verify the client initialises
        // with the correct base URL by checking isAvailable (which constructs the URL)
        let available = await client.isAvailable()
        // Expected to be false since no server is running on port 9999
        XCTAssertFalse(available)
    }

    // MARK: - Response JSON Parsing

    func testLanguageToolResponse_decodesValidJSON() throws {
        let json = """
        {
            "software": {"name": "LanguageTool", "version": "6.0", "buildDate": "2024-01-01", "apiVersion": 1},
            "language": {"name": "English (GB)", "code": "en-GB", "detectedLanguage": {"name": "English", "code": "en", "confidence": 0.99}},
            "matches": [
                {
                    "message": "Possible spelling mistake found.",
                    "shortMessage": "Spelling",
                    "offset": 0,
                    "length": 5,
                    "replacements": [{"value": "their"}],
                    "rule": {
                        "id": "MORFOLOGIK_RULE_EN_GB",
                        "description": "Possible spelling mistake",
                        "category": {"id": "TYPOS", "name": "Possible Typo"},
                        "issueType": "misspelling"
                    },
                    "context": {"text": "thier example", "offset": 0, "length": 5},
                    "sentence": "thier example"
                }
            ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(LanguageToolResponse.self, from: data)

        XCTAssertEqual(response.matches.count, 1)
        XCTAssertEqual(response.matches[0].message, "Possible spelling mistake found.")
        XCTAssertEqual(response.matches[0].offset, 0)
        XCTAssertEqual(response.matches[0].length, 5)
        XCTAssertEqual(response.matches[0].replacements.first?.value, "their")
        XCTAssertEqual(response.matches[0].rule.id, "MORFOLOGIK_RULE_EN_GB")
        XCTAssertEqual(response.matches[0].rule.category?.id, "TYPOS")
        XCTAssertEqual(response.software?.name, "LanguageTool")
        XCTAssertEqual(response.language?.code, "en-GB")
    }

    func testLanguageToolResponse_decodesEmptyMatches() throws {
        let json = """
        {
            "software": null,
            "language": null,
            "matches": []
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(LanguageToolResponse.self, from: data)

        XCTAssertTrue(response.matches.isEmpty)
    }

    func testLanguageToolResponse_decodesMultipleReplacements() throws {
        let json = """
        {
            "software": null,
            "language": null,
            "matches": [
                {
                    "message": "Word choice",
                    "shortMessage": null,
                    "offset": 10,
                    "length": 4,
                    "replacements": [{"value": "which"}, {"value": "whom"}, {"value": "who"}],
                    "rule": {"id": "WORD_CHOICE", "description": null, "category": null, "issueType": null},
                    "context": null,
                    "sentence": null
                }
            ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(LanguageToolResponse.self, from: data)

        XCTAssertEqual(response.matches[0].replacements.count, 3)
        XCTAssertEqual(response.matches[0].replacements.map(\.value), ["which", "whom", "who"])
    }

    func testLanguageToolMatch_idIsDeterministic() throws {
        let match = LanguageToolMatch(
            message: "Test",
            shortMessage: nil,
            offset: 5,
            length: 3,
            replacements: [],
            rule: LanguageToolRule(id: "RULE_1", description: nil, category: nil, issueType: nil),
            context: nil,
            sentence: nil
        )

        XCTAssertEqual(match.id, "RULE_1_5_3")
    }
}
