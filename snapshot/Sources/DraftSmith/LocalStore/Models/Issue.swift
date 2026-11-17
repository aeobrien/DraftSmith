import Foundation
import SwiftData

@Model
final class Issue {
    var id: UUID
    var status: String // IssueStatus.rawValue
    var pageIndex: Int
    var selectionText: String
    var annotationUUID: UUID?
    var ruleID: String?
    var message: String
    var category: String?
    var suggestions: Data? // JSON-encoded [String]
    var source: String // AnnotationSource.rawValue
    var severity: String // IssueSeverity.rawValue
    var createdAt: Date
    var resolvedAt: Date?
    var documentURL: String?
    var textOffset: Int?   // Character offset within the page's extracted text (for precise highlighting)
    var textLength: Int?   // Length of the flagged text in characters
    var rewrittenComment: String?  // Copilot-rewritten diplomatic version of the message

    init(
        id: UUID = UUID(),
        status: IssueStatus = .new,
        pageIndex: Int,
        selectionText: String,
        annotationUUID: UUID? = nil,
        ruleID: String? = nil,
        message: String,
        category: String? = nil,
        suggestions: [String] = [],
        source: AnnotationSource = .languageTool,
        severity: IssueSeverity = .warning,
        documentURL: String? = nil,
        textOffset: Int? = nil,
        textLength: Int? = nil
    ) {
        self.id = id
        self.status = status.rawValue
        self.pageIndex = pageIndex
        self.selectionText = selectionText
        self.annotationUUID = annotationUUID
        self.ruleID = ruleID
        self.message = message
        self.category = category
        self.suggestions = try? JSONEncoder().encode(suggestions)
        self.source = source.rawValue
        self.severity = severity.rawValue
        self.createdAt = Date()
        self.documentURL = documentURL
        self.textOffset = textOffset
        self.textLength = textLength
    }

    // MARK: - Computed Properties

    var issueStatus: IssueStatus {
        get { IssueStatus(rawValue: status) ?? .new }
        set { status = newValue.rawValue }
    }

    var issueSeverity: IssueSeverity {
        get { IssueSeverity(rawValue: severity) ?? .warning }
        set { severity = newValue.rawValue }
    }

    var issueSource: AnnotationSource {
        get { AnnotationSource(rawValue: source) ?? .languageTool }
        set { source = newValue.rawValue }
    }

    var suggestionsList: [String] {
        get {
            guard let data = suggestions else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            suggestions = try? JSONEncoder().encode(newValue)
        }
    }
}
