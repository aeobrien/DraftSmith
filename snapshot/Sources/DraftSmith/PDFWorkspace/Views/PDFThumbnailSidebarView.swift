import SwiftUI
import PDFKit

struct PDFThumbnailSidebarView: NSViewRepresentable {
    let pdfView: PDFView?

    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = CGSize(width: 100, height: 140)
        thumbnailView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        thumbnailView.pdfView = pdfView
        return thumbnailView
    }

    func updateNSView(_ thumbnailView: PDFThumbnailView, context: Context) {
        if thumbnailView.pdfView !== pdfView {
            thumbnailView.pdfView = pdfView
        }
    }
}
