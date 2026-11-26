import XCTest
@testable import DraftSmith

final class WordDiffEngineTests: XCTestCase {

    private let engine = WordDiffEngine()

    // MARK: - Unchanged

    func testDiff_identicalStrings_allUnchanged() {
        let segments = engine.diff(original: "hello world", replacement: "hello world")

        let nonUnchanged = segments.filter { !$0.isUnchanged }
        XCTAssertTrue(nonUnchanged.isEmpty, "Identical strings should have no deletions or insertions")

        let texts = segments.filter(\.isUnchanged).map(\.text)
        XCTAssertTrue(texts.contains("hello"))
        XCTAssertTrue(texts.contains("world"))
    }

    func testDiff_emptyStrings_returnsEmpty() {
        let segments = engine.diff(original: "", replacement: "")
        XCTAssertTrue(segments.isEmpty)
    }

    // MARK: - Insertion

    func testDiff_insertionOnly() {
        let segments = engine.diff(original: "hello world", replacement: "hello beautiful world")

        let inserted = segments.filter(\.isInserted)
        XCTAssertTrue(inserted.contains { $0.text == "beautiful" },
                       "Should detect 'beautiful' as inserted")
    }

    func testDiff_insertionAtEnd() {
        let segments = engine.diff(original: "hello", replacement: "hello world")

        let inserted = segments.filter(\.isInserted)
        XCTAssertTrue(inserted.contains { $0.text == "world" },
                       "Should detect 'world' as inserted at the end")
    }

    func testDiff_insertionFromEmpty() {
        let segments = engine.diff(original: "", replacement: "new text")

        let inserted = segments.filter(\.isInserted)
        XCTAssertFalse(inserted.isEmpty, "All words should be inserted when original is empty")
    }

    // MARK: - Deletion

    func testDiff_deletionOnly() {
        let segments = engine.diff(original: "hello beautiful world", replacement: "hello world")

        let deleted = segments.filter(\.isDeleted)
        XCTAssertTrue(deleted.contains { $0.text == "beautiful" },
                       "Should detect 'beautiful' as deleted")
    }

    func testDiff_deletionToEmpty() {
        let segments = engine.diff(original: "hello world", replacement: "")

        let deleted = segments.filter(\.isDeleted)
        XCTAssertFalse(deleted.isEmpty, "All words should be deleted when replacement is empty")
    }

    // MARK: - Mixed Changes

    func testDiff_wordReplacement() {
        let segments = engine.diff(original: "the quick fox", replacement: "the slow fox")

        let deleted = segments.filter(\.isDeleted)
        let inserted = segments.filter(\.isInserted)

        XCTAssertTrue(deleted.contains { $0.text == "quick" },
                       "Should detect 'quick' as deleted")
        XCTAssertTrue(inserted.contains { $0.text == "slow" },
                       "Should detect 'slow' as inserted")
    }

    func testDiff_multipleChanges() {
        let segments = engine.diff(
            original: "I think this needs revision soon",
            replacement: "I believe this requires revision immediately"
        )

        let deleted = segments.filter(\.isDeleted).map(\.text)
        let inserted = segments.filter(\.isInserted).map(\.text)
        let unchanged = segments.filter(\.isUnchanged).map(\.text)

        // "I", "this", "revision" should be unchanged
        XCTAssertTrue(unchanged.contains("I"))
        XCTAssertTrue(unchanged.contains("this"))
        XCTAssertTrue(unchanged.contains("revision"))

        // "think" -> "believe", "needs" -> "requires", "soon" -> "immediately"
        XCTAssertTrue(deleted.contains("think"))
        XCTAssertTrue(inserted.contains("believe"))
    }

    // MARK: - DiffSegment Properties

    func testDiffSegment_idPrefixes() {
        XCTAssertTrue(DiffSegment.unchanged("word").id.hasPrefix("u:"))
        XCTAssertTrue(DiffSegment.deleted("word").id.hasPrefix("d:"))
        XCTAssertTrue(DiffSegment.inserted("word").id.hasPrefix("i:"))
    }

    func testDiffSegment_textProperty() {
        XCTAssertEqual(DiffSegment.unchanged("hello").text, "hello")
        XCTAssertEqual(DiffSegment.deleted("removed").text, "removed")
        XCTAssertEqual(DiffSegment.inserted("added").text, "added")
    }

    func testDiffSegment_booleanFlags() {
        let unchanged = DiffSegment.unchanged("x")
        XCTAssertTrue(unchanged.isUnchanged)
        XCTAssertFalse(unchanged.isDeleted)
        XCTAssertFalse(unchanged.isInserted)

        let deleted = DiffSegment.deleted("x")
        XCTAssertFalse(deleted.isUnchanged)
        XCTAssertTrue(deleted.isDeleted)
        XCTAssertFalse(deleted.isInserted)

        let inserted = DiffSegment.inserted("x")
        XCTAssertFalse(inserted.isUnchanged)
        XCTAssertFalse(inserted.isDeleted)
        XCTAssertTrue(inserted.isInserted)
    }

    // MARK: - Punctuation Handling

    func testDiff_handlesPunctuation() {
        let segments = engine.diff(original: "Hello, world!", replacement: "Hello world")

        // The comma and exclamation mark are tokenized separately
        let deleted = segments.filter(\.isDeleted).map(\.text)
        XCTAssertTrue(deleted.contains(",") || deleted.contains("!"),
                       "Punctuation removal should appear in diff")
    }
}
