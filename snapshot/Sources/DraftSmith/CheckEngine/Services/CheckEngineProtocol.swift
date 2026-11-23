import Foundation
import PDFKit

@MainActor
protocol CheckEngineProtocol {
    func checkSelection(text: String, pageIndex: Int, documentURL: String?) async throws -> [Issue]
    func checkDocument(document: PDFDocument, documentURL: String?) async throws -> [Issue]
    func checkWithFastPath(text: String, pageIndex: Int, documentURL: String?) -> [Issue]
}
