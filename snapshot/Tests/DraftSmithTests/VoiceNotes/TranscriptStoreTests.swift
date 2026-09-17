import XCTest
@testable import DraftSmith

final class TranscriptStoreTests: XCTestCase {

    private let store = TranscriptStore()
    private var testUUID: UUID!
    private var testDirectory: URL!

    override func setUp() {
        super.setUp()
        testUUID = UUID()
        testDirectory = AppDirectories.transcriptDirectory(for: testUUID)
    }

    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }

    // MARK: - Save / Load Round-Trip

    func testSaveAndLoad_roundTrip() throws {
        let text = "This is a test transcript for the voice note."

        try store.save(text: text, annotationUUID: testUUID)

        let loaded = try store.load(annotationUUID: testUUID)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, text)
    }

    func testSaveMultiple_loadReturnsMostRecentFirst() throws {
        try store.save(text: "First transcript", annotationUUID: testUUID)
        // Add a small delay so file modification dates differ
        Thread.sleep(forTimeInterval: 0.1)
        try store.save(text: "Second transcript", annotationUUID: testUUID)

        let loaded = try store.load(annotationUUID: testUUID)
        XCTAssertEqual(loaded.count, 2)
        // Most recent should be first
        XCTAssertEqual(loaded.first, "Second transcript")
    }

    func testLoad_returnsEmptyForUnknownUUID() throws {
        let unknownUUID = UUID()
        let loaded = try store.load(annotationUUID: unknownUUID)
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Unicode Content

    func testSaveAndLoad_preservesUnicode() throws {
        let unicodeText = "Caf\u{00E9} na\u{00EF}ve r\u{00E9}sum\u{00E9} with emoji \u{1F4DD}"

        try store.save(text: unicodeText, annotationUUID: testUUID)

        let loaded = try store.load(annotationUUID: testUUID)
        XCTAssertEqual(loaded.first, unicodeText)
    }

    // MARK: - Empty Text

    func testSaveAndLoad_emptyString() throws {
        try store.save(text: "", annotationUUID: testUUID)

        let loaded = try store.load(annotationUUID: testUUID)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, "")
    }

    // MARK: - Multiline Text

    func testSaveAndLoad_multilineText() throws {
        let multiline = """
        Line one of the transcript.
        Line two with more content.
        Line three at the end.
        """

        try store.save(text: multiline, annotationUUID: testUUID)

        let loaded = try store.load(annotationUUID: testUUID)
        XCTAssertEqual(loaded.first, multiline)
    }

    // MARK: - Directory Creation

    func testSave_createsDirectoryIfNeeded() throws {
        let freshUUID = UUID()
        let dir = AppDirectories.transcriptDirectory(for: freshUUID)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))

        try store.save(text: "Test", annotationUUID: freshUUID)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }
}
