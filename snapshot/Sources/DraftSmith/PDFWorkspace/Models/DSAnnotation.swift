import Foundation
import PDFKit

struct DSAnnotation: Identifiable, Sendable, Equatable {
    let id: UUID
    var commentText: String
    let pageIndex: Int
    let selectionBounds: CGRect
    let metadata: AnnotationMetadata
    /// If non-nil, the comment was rewritten and this holds the original text for reverting.
    var originalCommentText: String?

    init(
        id: UUID = UUID(),
        commentText: String,
        pageIndex: Int,
        selectionBounds: CGRect,
        metadata: AnnotationMetadata? = nil,
        originalCommentText: String? = nil
    ) {
        self.id = id
        self.commentText = commentText
        self.pageIndex = pageIndex
        self.selectionBounds = selectionBounds
        self.metadata = metadata ?? AnnotationMetadata(dsUUID: id)
        self.originalCommentText = originalCommentText
    }

    /// Finds the matching PDFAnnotation on the given PDFDocument page.
    @MainActor
    func findPDFAnnotation(in document: PDFDocument) -> PDFAnnotation? {
        guard let page = document.page(at: pageIndex) else { return nil }
        for annotation in page.annotations {
            if let storedUUID = readDSUUID(from: annotation), storedUUID == metadata.dsUUID {
                return annotation
            }
        }
        return nil
    }

    @MainActor
    private func readDSUUID(from annotation: PDFAnnotation) -> UUID? {
        // Try custom annotation key first
        if let value = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)) as? String,
           let uuid = UUID(uuidString: value) {
            return uuid
        }
        // Fallback: parse from contents prefix
        if let contents = annotation.contents,
           contents.hasPrefix(AppConstants.dsUUIDFallbackPrefix),
           let endIndex = contents.firstIndex(of: Character(AppConstants.dsUUIDFallbackSuffix)) {
            let startIndex = contents.index(contents.startIndex, offsetBy: AppConstants.dsUUIDFallbackPrefix.count)
            let uuidString = String(contents[startIndex..<endIndex])
            return UUID(uuidString: uuidString)
        }
        return nil
    }
}
