import XCTest
@testable import DraftSmith

final class TokenCounterTests: XCTestCase {

    private let counter = TokenCounter()

    // MARK: - Approximate Counting

    func testCountTokens_emptyStringReturnsZero() {
        XCTAssertEqual(counter.countTokens(""), 0)
    }

    func testCountTokens_singleWordReturnsApproximateCount() {
        let count = counter.countTokens("hello")
        // 1 word * 1.3 = 1 (Int truncation)
        XCTAssertEqual(count, 1)
    }

    func testCountTokens_multipleWords() {
        let count = counter.countTokens("the quick brown fox jumps")
        // 5 words * 1.3 = 6 (Int(6.5) = 6)
        XCTAssertEqual(count, 6)
    }

    func testCountTokens_longerText() {
        let words = Array(repeating: "word", count: 100).joined(separator: " ")
        let count = counter.countTokens(words)
        // 100 words * 1.3 = 130
        XCTAssertEqual(count, 130)
    }

    func testCountTokens_arrayVariant() {
        let total = counter.countTokens(["hello world", "foo bar baz"])
        // "hello world" = 2 words * 1.3 = 2
        // "foo bar baz" = 3 words * 1.3 = 3
        // Total = 5
        XCTAssertEqual(total, 5)
    }

    func testCountTokens_emptyArray() {
        XCTAssertEqual(counter.countTokens([String]()), 0)
    }

    // MARK: - Fits

    func testFits_trueWhenUnderBudget() {
        XCTAssertTrue(counter.fits("hello world", budget: 10))
    }

    func testFits_trueWhenExactlyAtBudget() {
        let count = counter.countTokens("hello world")
        XCTAssertTrue(counter.fits("hello world", budget: count))
    }

    func testFits_falseWhenOverBudget() {
        XCTAssertFalse(counter.fits("hello world this is a long sentence", budget: 1))
    }

    // MARK: - Trim Function

    func testTrim_returnsOriginalWhenWithinBudget() {
        let text = "short text"
        let result = counter.trim(text, toFit: 100)
        XCTAssertEqual(result, text)
    }

    func testTrim_truncatesLongText() {
        let words = Array(repeating: "word", count: 100).joined(separator: " ")
        let result = counter.trim(words, toFit: 10)

        // Budget of 10 tokens -> Int(10 / 1.3) = 7 words
        let resultWords = result.split(separator: " ")
        // The last element might be "..." so we check count
        XCTAssertLessThan(resultWords.count, 100)
        XCTAssertTrue(result.hasSuffix("..."), "Trimmed text should end with ellipsis")
    }

    func testTrim_returnsEmptyForZeroBudget() {
        let result = counter.trim("some text here", toFit: 0)
        XCTAssertEqual(result, "")
    }

    func testTrim_preservesWholeWords() {
        let text = "The quick brown fox jumps over the lazy dog"
        let result = counter.trim(text, toFit: 5)

        // Budget of 5 tokens -> Int(5 / 1.3) = 3 words
        XCTAssertTrue(result.hasSuffix("..."))
        // Should not contain partial words
        let trimmedPart = result.replacingOccurrences(of: "...", with: "")
        let words = trimmedPart.split(separator: " ")
        for word in words {
            XCTAssertTrue(text.contains(word), "Trimmed output should contain only whole words from the original")
        }
    }

    func testTrim_emptyStringStaysEmpty() {
        let result = counter.trim("", toFit: 10)
        XCTAssertEqual(result, "")
    }
}
