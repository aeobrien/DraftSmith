import Foundation
import PDFKit

@MainActor
final class PDFAnnotationService: AnnotationServiceProtocol {

    func createHighlightWithComment(
        on document: PDFDocument,
        selection: PDFSelection,
        comment: String,
        source: AnnotationSource
    ) -> DSAnnotation? {
        guard let pages = selection.pages as? [PDFPage], let firstPage = pages.first else {
            return nil
        }

        let pageIndex = document.index(for: firstPage)
        let bounds = selection.bounds(for: firstPage)

        let metadata = AnnotationMetadata(source: source)

        // Create highlight annotation
        let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        highlight.color = .yellow
        highlight.contents = comment

        // Write ds_uuid as custom key
        highlight.setValue(
            metadata.dsUUID.uuidString,
            forAnnotationKey: PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)
        )

        // Also embed UUID in contents as fallback (in case custom key is stripped)
        let contentsWithUUID = "\(AppConstants.dsUUIDFallbackPrefix)\(metadata.dsUUID.uuidString)\(AppConstants.dsUUIDFallbackSuffix)\n\(comment)"
        highlight.contents = contentsWithUUID

        firstPage.addAnnotation(highlight)

        return DSAnnotation(
            id: metadata.dsUUID,
            commentText: comment,
            pageIndex: pageIndex,
            selectionBounds: bounds,
            metadata: metadata
        )
    }

    func updateComment(
        on document: PDFDocument,
        annotation: DSAnnotation,
        newComment: String
    ) -> DSAnnotation? {
        guard let pdfAnnotation = annotation.findPDFAnnotation(in: document) else {
            return nil
        }

        let contentsWithUUID = "\(AppConstants.dsUUIDFallbackPrefix)\(annotation.metadata.dsUUID.uuidString)\(AppConstants.dsUUIDFallbackSuffix)\n\(newComment)"
        pdfAnnotation.contents = contentsWithUUID

        var updated = annotation
        updated.commentText = newComment
        return updated
    }

    func removeAnnotation(
        from document: PDFDocument,
        annotation: DSAnnotation
    ) {
        guard let pdfAnnotation = annotation.findPDFAnnotation(in: document),
              let page = document.page(at: annotation.pageIndex) else {
            return
        }
        page.removeAnnotation(pdfAnnotation)
    }

    func readAnnotations(from document: PDFDocument) -> [DSAnnotation] {
        var result: [DSAnnotation] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard annotation.type == "Highlight" else { continue }
                guard let dsUUID = readDSUUID(from: annotation) else { continue }

                let commentText = extractCommentText(from: annotation.contents)
                let metadata = AnnotationMetadata(
                    dsUUID: dsUUID,
                    createdAt: Date(), // Cannot recover original date from PDF
                    source: .manual
                )

                let dsAnnotation = DSAnnotation(
                    id: dsUUID,
                    commentText: commentText,
                    pageIndex: pageIndex,
                    selectionBounds: annotation.bounds,
                    metadata: metadata
                )
                result.append(dsAnnotation)
            }
        }
        return result
    }

    func readDSUUID(from annotation: PDFAnnotation) -> UUID? {
        // Try custom annotation key
        if let value = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)) as? String,
           let uuid = UUID(uuidString: value) {
            return uuid
        }
        // Fallback: parse from contents prefix
        if let contents = annotation.contents {
            return extractUUIDFromContents(contents)
        }
        return nil
    }

    // MARK: - Private Helpers

    private func extractUUIDFromContents(_ contents: String) -> UUID? {
        guard contents.hasPrefix(AppConstants.dsUUIDFallbackPrefix) else { return nil }
        let startIndex = contents.index(
            contents.startIndex,
            offsetBy: AppConstants.dsUUIDFallbackPrefix.count
        )
        guard let endIndex = contents[startIndex...].firstIndex(of: Character(AppConstants.dsUUIDFallbackSuffix)) else {
            return nil
        }
        return UUID(uuidString: String(contents[startIndex..<endIndex]))
    }

    private func extractCommentText(from contents: String?) -> String {
        guard let contents = contents else { return "" }
        // Remove the UUID prefix if present
        if contents.hasPrefix(AppConstants.dsUUIDFallbackPrefix),
           let newlineIndex = contents.firstIndex(of: "\n") {
            return String(contents[contents.index(after: newlineIndex)...])
        }
        return contents
    }
}
