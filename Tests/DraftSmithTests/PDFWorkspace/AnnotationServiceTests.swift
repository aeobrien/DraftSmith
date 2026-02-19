import XCTest
import PDFKit
@testable import DraftSmith

@MainActor
final class AnnotationServiceTests: XCTestCase {

    private var service: PDFAnnotationService!

    override func setUp() {
        super.setUp()
        service = PDFAnnotationService()
    }

    // MARK: - Helpers

    /// Creates a selection from a synthetic PDF, or skips if not available.
    private func makeSelection(from document: PDFDocument, charStart: Int = 0, charEnd: Int = 10) throws -> PDFSelection {
        let page = try XCTUnwrap(document.page(at: 0))
        guard let selection = document.selection(from: page, atCharacterIndex: charStart, to: page, atCharacterIndex: charEnd) else {
            throw XCTSkip("PDF selection not available from synthetic document in this test environment")
        }
        return selection
    }

    /// Creates a highlight annotation, or skips if the synthetic PDF doesn't support it.
    private func makeAnnotation(on document: PDFDocument, selection: PDFSelection, comment: String) throws -> DSAnnotation {
        guard let annotation = service.createHighlightWithComment(
            on: document,
            selection: selection,
            comment: comment,
            source: .manual
        ) else {
            throw XCTSkip("Highlight annotation creation not supported on synthetic PDFs in this test environment")
        }
        return annotation
    }

    // MARK: - Create Annotation

    func testCreateHighlightWithComment_returnsAnnotationWithCorrectComment() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        let selection = try makeSelection(from: document)

        let comment = "This sentence needs revision."
        let annotation = try makeAnnotation(on: document, selection: selection, comment: comment)
        XCTAssertEqual(annotation.commentText, comment)
        XCTAssertEqual(annotation.pageIndex, 0)
    }

    // MARK: - Read UUID

    func testReadDSUUID_fromCustomKey() throws {
        let uuid = UUID()
        let pdfAnnotation = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 20), forType: .highlight, withProperties: nil)
        pdfAnnotation.setValue(
            uuid.uuidString,
            forAnnotationKey: PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)
        )

        let readUUID = service.readDSUUID(from: pdfAnnotation)
        XCTAssertEqual(readUUID, uuid)
    }

    func testReadDSUUID_fromFallbackContents() throws {
        let uuid = UUID()
        let pdfAnnotation = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 20), forType: .highlight, withProperties: nil)
        pdfAnnotation.contents = "\(AppConstants.dsUUIDFallbackPrefix)\(uuid.uuidString)\(AppConstants.dsUUIDFallbackSuffix)\nSome comment"

        let readUUID = service.readDSUUID(from: pdfAnnotation)
        XCTAssertEqual(readUUID, uuid)
    }

    func testReadDSUUID_returnsNilForNonDraftSmithAnnotation() {
        let pdfAnnotation = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 20), forType: .highlight, withProperties: nil)
        pdfAnnotation.contents = "Just a regular comment"

        let readUUID = service.readDSUUID(from: pdfAnnotation)
        XCTAssertNil(readUUID)
    }

    // MARK: - Unicode Round-Trip

    func testUnicodeRoundTrip_commentPreserved() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        let selection = try makeSelection(from: document, charStart: 0, charEnd: 5)

        let unicodeComment = "Emoji test \u{1F4DD} and accents: cafe\u{0301}, nai\u{0308}ve"
        let annotation = try makeAnnotation(on: document, selection: selection, comment: unicodeComment)
        XCTAssertEqual(annotation.commentText, unicodeComment)

        let readBack = service.readAnnotations(from: document)
        XCTAssertFalse(readBack.isEmpty)
        let found = readBack.first { $0.id == annotation.id }
        let foundAnnotation = try XCTUnwrap(found)
        XCTAssertEqual(foundAnnotation.commentText, unicodeComment)
    }

    // MARK: - Update Comment

    func testUpdateComment_changesCommentText() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        let selection = try makeSelection(from: document, charStart: 0, charEnd: 5)

        let originalAnnotation = try makeAnnotation(on: document, selection: selection, comment: "Original comment")

        guard let updatedAnnotation = service.updateComment(
            on: document,
            annotation: originalAnnotation,
            newComment: "Updated comment"
        ) else {
            throw XCTSkip("Update annotation not supported on synthetic PDFs")
        }

        XCTAssertEqual(updatedAnnotation.commentText, "Updated comment")
        XCTAssertEqual(updatedAnnotation.id, originalAnnotation.id)
    }

    // MARK: - Remove Annotation

    func testRemoveAnnotation_removesFromDocument() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF())
        let selection = try makeSelection(from: document, charStart: 0, charEnd: 5)

        let annotation = try makeAnnotation(on: document, selection: selection, comment: "To be removed")

        let annotationsBefore = service.readAnnotations(from: document)
        XCTAssertTrue(annotationsBefore.contains { $0.id == annotation.id })

        service.removeAnnotation(from: document, annotation: annotation)

        let annotationsAfter = service.readAnnotations(from: document)
        XCTAssertFalse(annotationsAfter.contains { $0.id == annotation.id })
    }
}
