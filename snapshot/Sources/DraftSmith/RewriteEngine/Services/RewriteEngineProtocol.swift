import Foundation

@MainActor
protocol RewriteEngineProtocol {
    func generateCommentVariants(
        passage: String,
        transcript: String,
        axes: PreferenceAxes
    ) async throws -> [CommentVariant]

    func generateRewriteVariants(
        passage: String,
        issue: Issue,
        axes: PreferenceAxes
    ) async throws -> [RewriteVariant]

    func rewriteComment(
        commentText: String,
        direction: CommentRewriteDirection
    ) async throws -> [CommentVariant]

    func regenerate(
        currentVariants: [CommentVariant],
        axes: PreferenceAxes,
        adjustedAxis: String?
    ) async throws -> [CommentVariant]

    func generateIssueComment(
        category: String,
        ruleID: String?,
        flaggedText: String,
        suggestion: String,
        message: String,
        exampleComments: [String]
    ) async throws -> String

    func polishComment(commentText: String) async throws -> String
}
