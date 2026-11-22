import Foundation

struct TokenCounter: Sendable {
    /// Approximate token count: words * 1.3
    /// This is a rough heuristic suitable for budget estimation.
    func countTokens(_ text: String) -> Int {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return Int(Double(words) * 1.3)
    }

    /// Count tokens for multiple strings, returning a total.
    func countTokens(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + countTokens($1) }
    }

    /// Check if the text fits within a given token budget.
    func fits(_ text: String, budget: Int) -> Bool {
        countTokens(text) <= budget
    }

    /// Trim text to fit within a token budget by removing content from the end.
    func trim(_ text: String, toFit budget: Int) -> String {
        guard !fits(text, budget: budget) else { return text }

        let words = text.split(whereSeparator: \.isWhitespace)
        let targetWords = Int(Double(budget) / 1.3)

        if targetWords <= 0 { return "" }
        if targetWords >= words.count { return text }

        return words[..<targetWords].joined(separator: " ") + "..."
    }
}
