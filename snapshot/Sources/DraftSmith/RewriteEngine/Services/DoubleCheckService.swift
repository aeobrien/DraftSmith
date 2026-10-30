import Foundation

struct DoubleCheckService: Sendable {
    /// Categories considered as spelling (auto-correctable)
    private static let spellingCategories: Set<String> = ["TYPOS", "SPELLING"]
    /// US→UK spelling rules to auto-correct
    private static let usToUkRulePrefix = "MORFOLOGIK_RULE_EN_GB"

    func check(text: String, client: LanguageToolClient) async throws -> DoubleCheckResult {
        let response = try await client.check(text: text, language: "en-GB")

        var correctedText = text
        var spellingCorrections: [SpellingCorrection] = []
        var styleFlags: [StyleFlag] = []

        // Process matches in reverse order (to preserve offsets)
        let sortedMatches = response.matches.sorted { $0.offset > $1.offset }

        for match in sortedMatches {
            let categoryID = match.rule.category?.id ?? ""
            let isSpelling = Self.spellingCategories.contains(categoryID) ||
                             match.rule.id.hasPrefix(Self.usToUkRulePrefix)

            if isSpelling, let replacement = match.replacements.first {
                // Auto-correct spelling (US→UK, typos)
                let nsText = correctedText as NSString
                let range = NSRange(location: match.offset, length: match.length)
                guard range.location + range.length <= nsText.length else { continue }

                let original = nsText.substring(with: range)
                correctedText = nsText.replacingCharacters(in: range, with: replacement.value)

                spellingCorrections.append(SpellingCorrection(
                    original: original,
                    corrected: replacement.value,
                    ruleID: match.rule.id
                ))
            } else {
                // Style/grammar flag — don't auto-correct
                let isSignificant = isSignificantFlag(match)
                styleFlags.append(StyleFlag(
                    message: match.message,
                    ruleID: match.rule.id,
                    severity: isSignificant ? .significantFlags : .minorFlags
                ))
            }
        }

        let overallSeverity: DoubleCheckSeverity
        if styleFlags.contains(where: { $0.severity == .significantFlags }) {
            overallSeverity = .significantFlags
        } else if !styleFlags.isEmpty {
            overallSeverity = .minorFlags
        } else {
            overallSeverity = .clean
        }

        return DoubleCheckResult(
            correctedText: correctedText,
            spellingCorrections: spellingCorrections,
            styleFlags: styleFlags,
            severity: overallSeverity
        )
    }

    // MARK: - Private

    private func isSignificantFlag(_ match: LanguageToolMatch) -> Bool {
        // Flags that could alter meaning are "significant"
        let significantCategories: Set<String> = ["GRAMMAR", "SEMANTICS", "CONFUSED_WORDS"]
        let categoryID = match.rule.category?.id ?? ""
        return significantCategories.contains(categoryID)
    }
}
