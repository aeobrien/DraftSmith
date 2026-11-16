import XCTest
@testable import DraftSmith

final class FeedbackAnalyzerTests: XCTestCase {

    private let analyzer = FeedbackAnalyzer()

    // MARK: - Diff Computation

    func testAnalyze_diffContainsCorrectSegments() {
        let result = analyzer.analyze(
            original: "The quick brown fox",
            edited: "The slow brown fox"
        )

        let deleted = result.diff.filter(\.isDeleted).map(\.text)
        let inserted = result.diff.filter(\.isInserted).map(\.text)

        XCTAssertTrue(deleted.contains("quick"))
        XCTAssertTrue(inserted.contains("slow"))
    }

    func testAnalyze_editDistanceIsNonNegative() {
        let result = analyzer.analyze(original: "hello", edited: "world")
        XCTAssertGreaterThanOrEqual(result.editDistance, 0)
    }

    func testAnalyze_editDistanceIsZeroForIdentical() {
        let result = analyzer.analyze(original: "same text", edited: "same text")
        XCTAssertEqual(result.editDistance, 0)
    }

    func testAnalyze_lengthChangeRatioForIdentical() {
        let result = analyzer.analyze(original: "same text", edited: "same text")
        XCTAssertEqual(result.lengthChangeRatio, 1.0, accuracy: 0.01)
    }

    func testAnalyze_lengthChangeRatioForShorterEdit() {
        let result = analyzer.analyze(
            original: "This is a really long sentence with many words in it",
            edited: "Short sentence"
        )
        XCTAssertLessThan(result.lengthChangeRatio, 1.0)
    }

    func testAnalyze_lengthChangeRatioForLongerEdit() {
        let result = analyzer.analyze(
            original: "Short",
            edited: "This is a much longer version of the text"
        )
        XCTAssertGreaterThan(result.lengthChangeRatio, 1.0)
    }

    // MARK: - Intent Tag: Brevity

    func testAnalyze_brevityTag_whenShortenedSignificantly() {
        // lengthChangeRatio < 0.7 triggers "brevity"
        let original = "This is a very long sentence that contains many unnecessary words and could be significantly shortened"
        let edited = "This sentence could be shorter"

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("brevity"),
                       "Significant shortening should produce 'brevity' tag, got: \(result.intentTags)")
    }

    func testAnalyze_moreDetailTag_whenLengthenedSignificantly() {
        // lengthChangeRatio > 1.3 triggers "more detail"
        let original = "Fix this."
        let edited = "Please consider revising this section to improve clarity and readability for the target audience."

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("more detail"),
                       "Significant lengthening should produce 'more detail' tag, got: \(result.intentTags)")
    }

    // MARK: - Intent Tag: Hedging

    func testAnalyze_lessHedgingTag_whenHedgingRemoved() {
        let original = "Perhaps this might need some revision."
        let edited = "This needs revision."

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("less hedging"),
                       "Removing hedging words should produce 'less hedging' tag, got: \(result.intentTags)")
    }

    func testAnalyze_moreHedgingTag_whenHedgingAdded() {
        let original = "This needs revision."
        let edited = "Perhaps this might need some revision."

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("more hedging"),
                       "Adding hedging words should produce 'more hedging' tag, got: \(result.intentTags)")
    }

    // MARK: - Intent Tag: Formality

    func testAnalyze_moreFormalTag_whenFormalLanguageAdded() {
        let original = "So we should do this because of that."
        let edited = "Therefore we should do this consequently."

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("more formal"),
                       "Adding formal markers should produce 'more formal' tag, got: \(result.intentTags)")
    }

    func testAnalyze_lessFormalTag_whenInformalLanguageAdded() {
        let original = "We shall proceed with the analysis."
        let edited = "We gonna proceed with the analysis."

        let result = analyzer.analyze(original: original, edited: edited)

        XCTAssertTrue(result.intentTags.contains("less formal"),
                       "Adding informal markers should produce 'less formal' tag, got: \(result.intentTags)")
    }

    // MARK: - No Tags for Minimal Changes

    func testAnalyze_noIntentTags_forMinimalChange() {
        let original = "The cat sat on the mat."
        let edited = "The dog sat on the mat."

        let result = analyzer.analyze(original: original, edited: edited)

        // Simple word swap should not trigger brevity, hedging, or formality tags
        XCTAssertFalse(result.intentTags.contains("brevity"))
        XCTAssertFalse(result.intentTags.contains("more hedging"))
        XCTAssertFalse(result.intentTags.contains("less hedging"))
    }

    // MARK: - Empty Input

    func testAnalyze_emptyOriginal() {
        let result = analyzer.analyze(original: "", edited: "New text added")
        XCTAssertGreaterThan(result.editDistance, 0)
    }

    func testAnalyze_emptyEdited() {
        let result = analyzer.analyze(original: "Some text removed", edited: "")
        XCTAssertGreaterThan(result.editDistance, 0)
        XCTAssertLessThan(result.lengthChangeRatio, 1.0)
    }
}
