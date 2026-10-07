import Foundation

struct WordDiffEngine: Sendable {
    /// Computes word-level diff between original and replacement text using LCS.
    func diff(original: String, replacement: String) -> [DiffSegment] {
        let originalWords = tokenize(original)
        let replacementWords = tokenize(replacement)

        let lcs = longestCommonSubsequence(originalWords, replacementWords)
        var segments: [DiffSegment] = []

        var origIndex = 0
        var replIndex = 0
        var lcsIndex = 0

        while lcsIndex < lcs.count {
            let lcsWord = lcs[lcsIndex]

            // Add deleted words from original
            while origIndex < originalWords.count && originalWords[origIndex] != lcsWord {
                segments.append(.deleted(originalWords[origIndex]))
                origIndex += 1
            }

            // Add inserted words from replacement
            while replIndex < replacementWords.count && replacementWords[replIndex] != lcsWord {
                segments.append(.inserted(replacementWords[replIndex]))
                replIndex += 1
            }

            // Add unchanged word
            segments.append(.unchanged(lcsWord))
            origIndex += 1
            replIndex += 1
            lcsIndex += 1
        }

        // Remaining words
        while origIndex < originalWords.count {
            segments.append(.deleted(originalWords[origIndex]))
            origIndex += 1
        }
        while replIndex < replacementWords.count {
            segments.append(.inserted(replacementWords[replIndex]))
            replIndex += 1
        }

        return segments
    }

    // MARK: - Private

    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in text {
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else if char.isPunctuation {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count

        guard m > 0, n > 0 else { return [] }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return result.reversed()
    }
}
