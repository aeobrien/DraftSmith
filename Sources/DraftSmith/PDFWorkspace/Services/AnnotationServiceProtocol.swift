import Foundation
import PDFKit

@MainActor
protocol AnnotationServiceProtocol {
    func createHighlightWithComment(
        on document: PDFDocument,
        selection: PDFSelection,
        comment: String,
        source: AnnotationSource
    ) -> DSAnnotation?

    func updateComment(
        on document: PDFDocument,
        annotation: DSAnnotation,
        newComment: String
    ) -> DSAnnotation?

    func removeAnnotation(
        from document: PDFDocument,
        annotation: DSAnnotation
    )

    func readAnnotations(from document: PDFDocument) -> [DSAnnotation]

    func readDSUUID(from annotation: PDFAnnotation) -> UUID?
}
