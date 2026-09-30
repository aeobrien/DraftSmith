import Foundation

struct FeedbackAnalyzer: Sendable {
    private let diffEngine = WordDiffEngine()

    func analyze(original: String, edited: String) -> (diff: [DiffSegment], lengthChangeRatio: Double, editDistance: Int, intentTags: [String]) {
        let diff = diffEngine.diff(original: original, replacement: edited)
        let lengthChangeRatio = Double(edited.count) / max(Double(original.count), 1)
        let editDistance = computeEditDistance(original, edited)
        let intentTags = deriveIntentTags(
            original: original,
            edited: edited,
            lengthChangeRatio: lengthChangeRatio,
            diff: diff
        )

        return (diff, lengthChangeRatio, editDistance, intentTags)
    }

    // MARK: - Private

    private func computeEditDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if aChars[i - 1] == bChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }

        return dp[m][n]
    }

    private func deriveIntentTags(original: String, edited: String, lengthChangeRatio: Double, diff: [DiffSegment]) -> [String] {
        var tags: [String] = []

        // Brevity
        if lengthChangeRatio < 0.7 {
            tags.append("brevity")
        } else if lengthChangeRatio > 1.3 {
            tags.append("more detail")
        }

        // Hedging detection
        let hedgingWords = ["perhaps", "maybe", "might", "could possibly", "somewhat", "rather"]
        let originalLower = original.lowercased()
        let editedLower = edited.lowercased()

        let removedHedging = hedgingWords.filter { originalLower.contains($0) && !editedLower.contains($0) }
        if !removedHedging.isEmpty {
            tags.append("less hedging")
        }

        let addedHedging = hedgingWords.filter { !originalLower.contains($0) && editedLower.contains($0) }
        if !addedHedging.isEmpty {
            tags.append("more hedging")
        }

        // Formality shifts
        let informalMarkers = ["gonna", "wanna", "kinda", "don't", "can't", "won't"]
        let formalMarkers = ["shall", "therefore", "furthermore", "consequently"]

        let addedFormal = formalMarkers.filter { !originalLower.contains($0) && editedLower.contains($0) }
        if !addedFormal.isEmpty {
            tags.append("more formal")
        }

        let addedInformal = informalMarkers.filter { !originalLower.contains($0) && editedLower.contains($0) }
        if !addedInformal.isEmpty {
            tags.append("less formal")
        }

        // Specificity
        let deletedCount = diff.filter(\.isDeleted).count
        let insertedCount = diff.filter(\.isInserted).count
        if insertedCount > deletedCount * 2 {
            tags.append("more specific")
        }

        return tags
    }
}
