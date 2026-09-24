import XCTest
import SwiftData
@testable import DraftSmith

@MainActor
final class IssueManagerTests: XCTestCase {

    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var issueManager: IssueManager!

    override func setUp() {
        super.setUp()
        container = TestHelpers.createTestModelContainer()
        modelContext = container.mainContext
        issueManager = IssueManager(modelContext: modelContext)
    }

    // MARK: - Create (Add)

    func testAddIssue_persistsIssue() {
        let issue = Issue(
            pageIndex: 0,
            selectionText: "teh",
            message: "Possible typo",
            suggestions: ["the"],
            severity: .warning
        )

        issueManager.addIssue(issue)

        let fetched = issueManager.fetchIssues()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.selectionText, "teh")
        XCTAssertEqual(fetched.first?.message, "Possible typo")
    }

    func testAddMultipleIssues() {
        for i in 0..<5 {
            let issue = Issue(
                pageIndex: i,
                selectionText: "word\(i)",
                message: "Issue \(i)"
            )
            issueManager.addIssue(issue)
        }

        let fetched = issueManager.fetchIssues()
        XCTAssertEqual(fetched.count, 5)
    }

    // MARK: - Read

    func testFetchIssues_returnsAllWhenNoFilter() {
        issueManager.addIssue(Issue(pageIndex: 0, selectionText: "a", message: "A"))
        issueManager.addIssue(Issue(pageIndex: 1, selectionText: "b", message: "B"))

        let all = issueManager.fetchIssues()
        XCTAssertEqual(all.count, 2)
    }

    func testFetchIssues_filtersByDocumentURL() {
        let issue1 = Issue(pageIndex: 0, selectionText: "a", message: "A", documentURL: "/doc1.pdf")
        let issue2 = Issue(pageIndex: 0, selectionText: "b", message: "B", documentURL: "/doc2.pdf")

        issueManager.addIssue(issue1)
        issueManager.addIssue(issue2)

        let doc1Issues = issueManager.fetchIssues(for: "/doc1.pdf")
        XCTAssertEqual(doc1Issues.count, 1)
        XCTAssertEqual(doc1Issues.first?.selectionText, "a")
    }

    // MARK: - Update (Resolve / Dismiss)

    func testResolveIssue_changesStatusToResolved() {
        let issue = Issue(pageIndex: 0, selectionText: "x", message: "Test")
        issueManager.addIssue(issue)
        XCTAssertEqual(issue.issueStatus, .new)

        issueManager.resolveIssue(issue)
        XCTAssertEqual(issue.issueStatus, .resolved)
        XCTAssertNotNil(issue.resolvedAt)
    }

    func testResolveIssue_setsAnnotationUUID() {
        let issue = Issue(pageIndex: 0, selectionText: "x", message: "Test")
        issueManager.addIssue(issue)

        let uuid = UUID()
        issueManager.resolveIssue(issue, annotationUUID: uuid)
        XCTAssertEqual(issue.annotationUUID, uuid)
    }

    func testDismissIssue_changesStatusToDismissed() {
        let issue = Issue(pageIndex: 0, selectionText: "x", message: "Test")
        issueManager.addIssue(issue)

        issueManager.dismissIssue(issue)
        XCTAssertEqual(issue.issueStatus, .dismissed)
    }

    // MARK: - Delete

    func testDeleteIssue_removesFromStore() {
        let issue = Issue(pageIndex: 0, selectionText: "x", message: "Test")
        issueManager.addIssue(issue)
        XCTAssertEqual(issueManager.fetchIssues().count, 1)

        issueManager.deleteIssue(issue)
        XCTAssertEqual(issueManager.fetchIssues().count, 0)
    }

    // MARK: - Counts

    func testIssueCounts_categorisesCorrectly() {
        let newIssue = Issue(pageIndex: 0, selectionText: "a", message: "New")
        let resolvedIssue = Issue(pageIndex: 0, selectionText: "b", message: "Resolved")
        let dismissedIssue = Issue(pageIndex: 0, selectionText: "c", message: "Dismissed")

        issueManager.addIssue(newIssue)
        issueManager.addIssue(resolvedIssue)
        issueManager.addIssue(dismissedIssue)

        issueManager.resolveIssue(resolvedIssue)
        issueManager.dismissIssue(dismissedIssue)

        let counts = issueManager.issueCounts()
        XCTAssertEqual(counts.total, 3)
        XCTAssertEqual(counts.new, 1)
        XCTAssertEqual(counts.resolved, 1)
        XCTAssertEqual(counts.dismissed, 1)
    }

    func testIssueCounts_filtersByDocumentURL() {
        let issue1 = Issue(pageIndex: 0, selectionText: "a", message: "A", documentURL: "/doc.pdf")
        let issue2 = Issue(pageIndex: 0, selectionText: "b", message: "B", documentURL: "/other.pdf")

        issueManager.addIssue(issue1)
        issueManager.addIssue(issue2)

        let counts = issueManager.issueCounts(for: "/doc.pdf")
        XCTAssertEqual(counts.total, 1)
        XCTAssertEqual(counts.new, 1)
    }

    // MARK: - Filtering by Status

    func testFetchIssues_filtersByStatus() {
        let newIssue = Issue(pageIndex: 0, selectionText: "a", message: "New")
        let resolvedIssue = Issue(pageIndex: 0, selectionText: "b", message: "Resolved")

        issueManager.addIssue(newIssue)
        issueManager.addIssue(resolvedIssue)
        issueManager.resolveIssue(resolvedIssue)

        let newOnly = issueManager.fetchIssues(status: .new)
        XCTAssertEqual(newOnly.count, 1)
        XCTAssertEqual(newOnly.first?.message, "New")

        let resolvedOnly = issueManager.fetchIssues(status: .resolved)
        XCTAssertEqual(resolvedOnly.count, 1)
        XCTAssertEqual(resolvedOnly.first?.message, "Resolved")
    }

    // MARK: - Issue Properties

    func testIssue_suggestionsListRoundTrip() {
        let issue = Issue(
            pageIndex: 0,
            selectionText: "teh",
            message: "Typo",
            suggestions: ["the", "they", "then"]
        )
        issueManager.addIssue(issue)

        XCTAssertEqual(issue.suggestionsList, ["the", "they", "then"])
    }

    func testIssue_computedPropertiesMatchInitValues() {
        let issue = Issue(
            pageIndex: 3,
            selectionText: "test",
            message: "msg",
            source: .llmRewrite,
            severity: .info
        )

        XCTAssertEqual(issue.issueStatus, .new)
        XCTAssertEqual(issue.issueSeverity, .info)
        XCTAssertEqual(issue.issueSource, .llmRewrite)
    }
}
