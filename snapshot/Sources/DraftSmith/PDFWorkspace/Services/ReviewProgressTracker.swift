import Foundation

@Observable
@MainActor
final class ReviewProgressTracker {
    private(set) var pagesVisited: Set<Int> = []
    private(set) var totalPages: Int = 0
    private(set) var totalIssues: Int = 0
    private(set) var newIssues: Int = 0
    private(set) var resolvedIssues: Int = 0
    private(set) var dismissedIssues: Int = 0

    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesVisited.count) / Double(totalPages)
    }

    var progressText: String {
        let pagesText = "\(pagesVisited.count)/\(totalPages) pages"
        let issuesText = "\(totalIssues) issues (\(newIssues) new, \(resolvedIssues) resolved, \(dismissedIssues) dismissed)"
        return "\(pagesText) \u{2014} \(issuesText)"
    }

    func setTotalPages(_ count: Int) {
        totalPages = count
    }

    func markPageVisited(_ pageIndex: Int) {
        pagesVisited.insert(pageIndex)
    }

    func updateIssueCounts(total: Int, new: Int, resolved: Int, dismissed: Int) {
        totalIssues = total
        newIssues = new
        resolvedIssues = resolved
        dismissedIssues = dismissed
    }

    func reset() {
        pagesVisited = []
        totalPages = 0
        totalIssues = 0
        newIssues = 0
        resolvedIssues = 0
        dismissedIssues = 0
    }
}
