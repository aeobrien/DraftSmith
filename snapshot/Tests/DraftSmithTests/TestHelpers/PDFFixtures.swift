import Foundation
import PDFKit
@testable import DraftSmith

enum PDFFixtures {
    /// Creates a synthetic single-page PDF in memory for testing.
    @MainActor
    static func createSinglePagePDF(text: String = "This is a test document with some sample text for proofreading.") -> PDFDocument? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let renderer = NSMutableData()

        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: renderer),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPage(mediaBox: &mediaBox)

        // Draw text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let nsText = text as NSString
        nsText.draw(at: CGPoint(x: 72, y: 700), withAttributes: attrs)

        context.endPage()
        context.closePDF()

        return PDFDocument(data: renderer as Data)
    }

    /// Creates a multi-page PDF with given page texts.
    @MainActor
    static func createMultiPagePDF(pageTexts: [String]) -> PDFDocument? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = NSMutableData()

        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: renderer),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        for text in pageTexts {
            context.beginPage(mediaBox: &mediaBox)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
            (text as NSString).draw(at: CGPoint(x: 72, y: 700), withAttributes: attrs)
            context.endPage()
        }

        context.closePDF()
        return PDFDocument(data: renderer as Data)
    }
}
