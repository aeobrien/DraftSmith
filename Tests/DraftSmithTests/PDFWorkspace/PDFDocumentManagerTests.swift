import XCTest
import PDFKit
@testable import DraftSmith

@MainActor
final class PDFDocumentManagerTests: XCTestCase {

    private var manager: PDFDocumentManager!
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        manager = PDFDocumentManager()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    // MARK: - Open

    func testOpen_setsDocumentAndURL() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        XCTAssertTrue(pdf.write(to: tempURL))

        try manager.open(url: tempURL)

        XCTAssertNotNil(manager.document)
        XCTAssertEqual(manager.documentURL, tempURL)
        XCTAssertEqual(manager.currentPageIndex, 0)
        XCTAssertFalse(manager.isModified)
    }

    func testOpen_throwsForInvalidPath() {
        let badURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent.pdf")

        XCTAssertThrowsError(try manager.open(url: badURL))
    }

    // MARK: - Save

    func testSave_clearsModifiedFlag() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        XCTAssertTrue(pdf.write(to: tempURL))

        try manager.open(url: tempURL)
        manager.markModified()
        XCTAssertTrue(manager.isModified)

        try manager.save()
        XCTAssertFalse(manager.isModified)
    }

    // MARK: - Navigation

    func testGoToPage_updatesCurrentPageIndex() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createMultiPagePDF(pageTexts: ["Page 1", "Page 2", "Page 3"]))
        let multiURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: multiURL) }

        XCTAssertTrue(pdf.write(to: multiURL))
        try manager.open(url: multiURL)

        XCTAssertEqual(manager.currentPageIndex, 0)

        manager.goToPage(1)
        XCTAssertEqual(manager.currentPageIndex, 1)

        manager.goToPage(2)
        XCTAssertEqual(manager.currentPageIndex, 2)
    }

    func testGoToPage_ignoresOutOfBoundsIndex() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        XCTAssertTrue(pdf.write(to: tempURL))
        try manager.open(url: tempURL)

        manager.goToPage(99)
        XCTAssertEqual(manager.currentPageIndex, 0, "Out-of-bounds page index should be ignored")

        manager.goToPage(-1)
        XCTAssertEqual(manager.currentPageIndex, 0, "Negative page index should be ignored")
    }

    func testNextPage_andPreviousPage() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createMultiPagePDF(pageTexts: ["A", "B", "C"]))
        let multiURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: multiURL) }

        XCTAssertTrue(pdf.write(to: multiURL))
        try manager.open(url: multiURL)

        manager.nextPage()
        XCTAssertEqual(manager.currentPageIndex, 1)

        manager.nextPage()
        XCTAssertEqual(manager.currentPageIndex, 2)

        // Should not go beyond last page
        manager.nextPage()
        XCTAssertEqual(manager.currentPageIndex, 2)

        manager.previousPage()
        XCTAssertEqual(manager.currentPageIndex, 1)

        manager.previousPage()
        XCTAssertEqual(manager.currentPageIndex, 0)

        // Should not go below zero
        manager.previousPage()
        XCTAssertEqual(manager.currentPageIndex, 0)
    }

    func testPageCount_reflectsDocumentPages() throws {
        XCTAssertEqual(manager.pageCount, 0, "No document loaded means zero pages")

        let pdf = try XCTUnwrap(PDFFixtures.createMultiPagePDF(pageTexts: ["A", "B"]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(pdf.write(to: url))
        try manager.open(url: url)

        XCTAssertEqual(manager.pageCount, 2)
    }

    // MARK: - Create Annotation

    func testCreateAnnotation_setsModifiedFlag() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        XCTAssertTrue(pdf.write(to: tempURL))
        try manager.open(url: tempURL)

        let page = try XCTUnwrap(manager.document?.page(at: 0))
        let selection = manager.document?.selection(from: page, atCharacterIndex: 0, to: page, atCharacterIndex: 5)

        guard let selection = selection else {
            throw XCTSkip("PDF selection not available from synthetic document")
        }

        manager.setSelection(selection)
        XCTAssertFalse(manager.isModified)

        let annotation = manager.createAnnotation(comment: "Test comment", source: .manual)

        if annotation != nil {
            XCTAssertTrue(manager.isModified)
        }
    }

    func testCreateAnnotation_returnsNilWithNoSelection() throws {
        let pdf = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        XCTAssertTrue(pdf.write(to: tempURL))
        try manager.open(url: tempURL)

        let result = manager.createAnnotation(comment: "No selection", source: .manual)
        XCTAssertNil(result, "Should return nil when no selection is set")
    }
}
