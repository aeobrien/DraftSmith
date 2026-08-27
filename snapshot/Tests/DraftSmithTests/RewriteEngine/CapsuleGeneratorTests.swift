import XCTest
@testable import DraftSmith

final class CapsuleGeneratorTests: XCTestCase {

    // MARK: - 500-Token Enforcement

    func testTokenCounter_enforcesMaxCapsuleTokens() {
        let counter = TokenCounter()
        let maxTokens = AppConstants.capsuleMaxTokens

        // Generate text that exceeds 500 tokens
        let words = Array(repeating: "word", count: 600).joined(separator: " ")
        let tokenCount = counter.countTokens(words)
        XCTAssertGreaterThan(tokenCount, maxTokens, "Generated text should exceed the capsule limit")

        // Trim to fit
        let trimmed = counter.trim(words, toFit: maxTokens)
        let trimmedTokens = counter.countTokens(trimmed)
        XCTAssertLessThanOrEqual(trimmedTokens, maxTokens,
                                  "Trimmed capsule should be at or under \(maxTokens) tokens")
    }

    func testTokenCounter_textUnderLimitIsNotTrimmed() {
        let counter = TokenCounter()
        let maxTokens = AppConstants.capsuleMaxTokens

        let shortText = "Brief capsule: prefer active voice and British spelling."
        XCTAssertLessThan(counter.countTokens(shortText), maxTokens)

        let result = counter.trim(shortText, toFit: maxTokens)
        XCTAssertEqual(result, shortText, "Text under limit should not be modified")
    }

    func testCapsuleMaxTokens_equals500() {
        XCTAssertEqual(AppConstants.capsuleMaxTokens, 500)
    }

    // MARK: - StyleCapsuleResponse Decoding

    func testStyleCapsuleResponse_decodesCorrectly() throws {
        let json = """
        {
            "capsule_text": "This editor prefers concise, formal British English.",
            "key_tendencies": ["brevity", "British spelling", "active voice"],
            "token_count": 12
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(StyleCapsuleResponse.self, from: data)

        XCTAssertEqual(response.capsuleText, "This editor prefers concise, formal British English.")
        XCTAssertEqual(response.keyTendencies, ["brevity", "British spelling", "active voice"])
        XCTAssertEqual(response.tokenCount, 12)
    }

    func testStyleCapsuleResponse_parsedViaLLMResponseParser() throws {
        let parser = LLMResponseParser()
        let json = """
        ```json
        {
            "capsule_text": "Formal tone, no hedging.",
            "key_tendencies": ["direct"],
            "token_count": 6
        }
        ```
        """

        let response = try parser.parse(json, as: StyleCapsuleResponse.self)
        XCTAssertEqual(response.capsuleText, "Formal tone, no hedging.")
        XCTAssertEqual(response.keyTendencies, ["direct"])
    }

    // MARK: - StyleCapsule Model

    @MainActor
    func testStyleCapsule_modelProperties() {
        let capsule = StyleCapsule(
            capsuleText: "Test capsule text",
            keyTendencies: ["tendency1", "tendency2"],
            tokenCount: 42,
            isPendingApproval: true
        )

        XCTAssertEqual(capsule.capsuleText, "Test capsule text")
        XCTAssertEqual(capsule.keyTendencies, ["tendency1", "tendency2"])
        XCTAssertEqual(capsule.tokenCount, 42)
        XCTAssertTrue(capsule.isPendingApproval)
        XCTAssertFalse(capsule.isActive)
        XCTAssertNil(capsule.activatedAt)
    }

    // MARK: - Enforcement via Trim

    func testCapsuleTrimming_preservesContentUnderLimit() {
        let counter = TokenCounter()
        let capsuleText = "The editor prefers active voice, British spelling, and concise phrasing."
        let tokenCount = counter.countTokens(capsuleText)

        XCTAssertLessThan(tokenCount, AppConstants.capsuleMaxTokens)

        // If under limit, no trimming needed
        if counter.countTokens(capsuleText) <= AppConstants.capsuleMaxTokens {
            let result = counter.trim(capsuleText, toFit: AppConstants.capsuleMaxTokens)
            XCTAssertEqual(result, capsuleText)
        }
    }

    func testCapsuleTrimming_truncatesOverLimitText() {
        let counter = TokenCounter()
        // 1000 words * 1.3 = 1300 tokens, well over 500
        let longCapsule = Array(repeating: "tendency", count: 1000).joined(separator: " ")
        XCTAssertGreaterThan(counter.countTokens(longCapsule), AppConstants.capsuleMaxTokens)

        let trimmed = counter.trim(longCapsule, toFit: AppConstants.capsuleMaxTokens)
        XCTAssertLessThanOrEqual(counter.countTokens(trimmed), AppConstants.capsuleMaxTokens)
        XCTAssertTrue(trimmed.hasSuffix("..."))
    }
}
