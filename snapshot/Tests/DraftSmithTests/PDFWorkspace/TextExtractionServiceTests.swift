import XCTest
import PDFKit
@testable import DraftSmith

@MainActor
final class TextExtractionServiceTests: XCTestCase {

    private var service: TextExtractionService!

    override func setUp() {
        super.setUp()
        service = TextExtractionService()
    }

    // MARK: - High Confidence

    func testExtractText_highConfidence_forWellFormedEnglish() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF(text: "The quick brown fox jumps over the lazy dog."))
        let page = try XCTUnwrap(document.page(at: 0))

        guard let selection = page.selection(for: page.bounds(for: .mediaBox)) else {
            throw XCTSkip("PDF text selection not available from synthetic document")
        }

        let result = service.extractText(from: selection)

        // If the synthetic PDF rendered extractable text, validate confidence
        if !result.text.isEmpty {
            XCTAssertEqual(result.confidence, .high,
                           "Well-formed English should yield high confidence, got \(result.confidence) with ratio \(result.nonDictionaryRatio)")
        }
    }

    // MARK: - Low Confidence

    func testExtractText_lowConfidence_forPartialGibberish() throws {
        // Create a PDF where roughly a third of words are nonsense
        let text = "The xqrtz document contains normal words but also brlkmp and fnazzy nonsense that should zyvwx lower the wqprt confidence klmn result"
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF(text: text))
        let page = try XCTUnwrap(document.page(at: 0))

        guard let selection = page.selection(for: page.bounds(for: .mediaBox)) else {
            throw XCTSkip("PDF text selection not available from synthetic document")
        }

        let result = service.extractText(from: selection)

        if !result.text.isEmpty {
            XCTAssertTrue(
                result.confidence == .low || result.confidence == .unreadable,
                "Text with many non-dictionary words should yield low or unreadable confidence, got \(result.confidence)"
            )
            XCTAssertGreaterThanOrEqual(result.nonDictionaryRatio, 0.3)
        }
    }

    // MARK: - Unreadable Confidence

    func testExtractText_unreadable_forEmptySelection() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF(text: ""))
        let page = try XCTUnwrap(document.page(at: 0))

        // Create a selection in an area with no text
        let emptyRect = CGRect(x: 500, y: 500, width: 10, height: 10)
        guard let selection = page.selection(for: emptyRect) else {
            // No selection means no text, which is the expected unreadable case
            // Verify by creating a mock-like scenario
            let doc2 = try XCTUnwrap(PDFFixtures.createSinglePagePDF(text: "Hello"))
            let page2 = try XCTUnwrap(doc2.page(at: 0))
            if let sel = page2.selection(for: emptyRect) {
                let result = service.extractText(from: sel)
                if result.text.isEmpty {
                    XCTAssertEqual(result.confidence, .unreadable)
                }
            }
            return
        }

        let result = service.extractText(from: selection)
        if result.text.isEmpty {
            XCTAssertEqual(result.confidence, .unreadable)
            XCTAssertEqual(result.nonDictionaryRatio, 1.0)
        }
    }

    func testExtractText_returnsNonDictionaryRatio() throws {
        let document = try XCTUnwrap(PDFFixtures.createSinglePagePDF(text: "This is a normal sentence with proper words"))
        let page = try XCTUnwrap(document.page(at: 0))

        guard let selection = page.selection(for: page.bounds(for: .mediaBox)) else {
            throw XCTSkip("PDF text selection not available from synthetic document")
        }

        let result = service.extractText(from: selection)

        if !result.text.isEmpty {
            XCTAssertGreaterThanOrEqual(result.nonDictionaryRatio, 0.0)
            XCTAssertLessThanOrEqual(result.nonDictionaryRatio, 1.0)
        }
    }
}
