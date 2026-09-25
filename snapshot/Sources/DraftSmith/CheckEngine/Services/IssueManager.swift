import Foundation
import SwiftData

@Observable
@MainActor
final class IssueManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func addIssue(_ issue: Issue) {
        modelContext.insert(issue)
        try? modelContext.save()
    }

    func resolveIssue(_ issue: Issue, annotationUUID: UUID? = nil) {
        issue.issueStatus = .resolved
        issue.resolvedAt = Date()
        if let uuid = annotationUUID {
            issue.annotationUUID = uuid
        }
        try? modelContext.save()
    }

    func dismissIssue(_ issue: Issue) {
        issue.issueStatus = .dismissed
        try? modelContext.save()
    }

    /// Dismisses all new issues matching the same flagged text (case-insensitive).
    func dismissAllMatching(selectionText: String, documentURL: String?) {
        let issues = fetchIssues(for: documentURL, status: .new)
        for issue in issues where issue.selectionText.lowercased() == selectionText.lowercased() {
            issue.issueStatus = .dismissed
        }
        try? modelContext.save()
    }

    /// Dismisses all new issues matching the same rule ID.
    func dismissAllByRule(ruleID: String, documentURL: String?) {
        let issues = fetchIssues(for: documentURL, status: .new)
        for issue in issues where issue.ruleID == ruleID {
            issue.issueStatus = .dismissed
        }
        try? modelContext.save()
    }

    func deleteIssue(_ issue: Issue) {
        modelContext.delete(issue)
        try? modelContext.save()
    }

    /// Removes all "new" (unresolved, undismissed) issues for a document.
    func clearNewIssues(for documentURL: String?) {
        let issues = fetchIssues(for: documentURL, status: .new)
        for issue in issues {
            modelContext.delete(issue)
        }
        try? modelContext.save()
    }

    /// Removes ALL issues for a document regardless of status.
    /// Called before re-checking to prevent duplicates from accumulating across runs.
    func clearAllIssues(for documentURL: String?) {
        let issues = fetchIssues(for: documentURL)
        for issue in issues {
            modelContext.delete(issue)
        }
        try? modelContext.save()
    }

    func fetchIssues(for documentURL: String? = nil, status: IssueStatus? = nil) -> [Issue] {
        let descriptor = FetchDescriptor<Issue>(
            sortBy: [SortDescriptor(\.pageIndex), SortDescriptor(\.createdAt)]
        )

        var results = (try? modelContext.fetch(descriptor)) ?? []

        if let documentURL = documentURL {
            results = results.filter { $0.documentURL == documentURL }
        }

        if let status = status {
            results = results.filter { $0.issueStatus == status }
        }

        return results
    }

    func issueCounts(for documentURL: String? = nil) -> (total: Int, new: Int, resolved: Int, dismissed: Int) {
        let allIssues = fetchIssues(for: documentURL)
        let newCount = allIssues.filter { $0.issueStatus == .new }.count
        let resolvedCount = allIssues.filter { $0.issueStatus == .resolved }.count
        let dismissedCount = allIssues.filter { $0.issueStatus == .dismissed }.count
        return (allIssues.count, newCount, resolvedCount, dismissedCount)
    }
}
