import Foundation

struct LanguageToolMatchConverter {
    let customDictionary: Set<String>
    let terminologyPreferences: [TerminologyEntry]
    let severityOverrides: [String: IssueSeverity]

    init(
        customDictionary: [String] = [],
        terminologyPreferences: [TerminologyEntry] = [],
        severityOverrides: [String: IssueSeverity] = [:]
    ) {
        self.customDictionary = Set(customDictionary.map { $0.lowercased() })
        self.terminologyPreferences = terminologyPreferences
        self.severityOverrides = severityOverrides
    }

    func convert(
        match: LanguageToolMatch,
        selectionText: String,
        pageIndex: Int,
        documentURL: String?,
        textOffset: Int? = nil
    ) -> Issue? {
        // Extract the flagged word
        let nsText = selectionText as NSString
        let flaggedRange = NSRange(location: match.offset, length: match.length)
        guard flaggedRange.location + flaggedRange.length <= nsText.length else { return nil }
        let flaggedWord = nsText.substring(with: flaggedRange)

        // Skip whitespace-only or empty matches
        if flaggedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        // Skip if the word is in the custom dictionary
        if customDictionary.contains(flaggedWord.lowercased()) {
            return nil
        }

        // Skip apostrophe false positives: PDF extraction often splits contractions
        // (e.g. "didn't" → "didn" + "'" + "t"), causing LanguageTool to flag "didn"
        // and suggest "didn't" when the original text already has the contraction.
        if isFalseApostropheMatch(flaggedWord: flaggedWord, match: match, fullText: selectionText) {
            return nil
        }

        let suggestions = match.replacements.map(\.value)
        let severity = severityOverrides[match.rule.id] ?? defaultSeverity(for: match)

        return Issue(
            pageIndex: pageIndex,
            selectionText: flaggedWord,
            ruleID: match.rule.id,
            message: match.message,
            category: match.rule.category?.name,
            suggestions: suggestions,
            source: .languageTool,
            severity: severity,
            documentURL: documentURL,
            textOffset: textOffset ?? match.offset,
            textLength: match.length
        )
    }

    func convertAll(
        response: LanguageToolResponse,
        selectionText: String,
        pageIndex: Int,
        documentURL: String?
    ) -> [Issue] {
        let allIssues = response.matches.compactMap { match in
            convert(match: match, selectionText: selectionText, pageIndex: pageIndex, documentURL: documentURL)
        }

        // Deduplicate: when multiple rules flag the same text on the same page,
        // keep only the first match (LanguageTool returns most specific rules first).
        var seen = Set<String>()
        return allIssues.filter { issue in
            let key = "\(issue.pageIndex)_\(issue.selectionText)"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Private

    /// Detects false positives caused by PDF text extraction splitting words at apostrophes.
    /// Example: "didn't" extracted as "didn" + "'" + "t" → LT flags "didn" and suggests "didn't".
    /// We check if the characters immediately following the flagged range form the contraction.
    private func isFalseApostropheMatch(flaggedWord: String, match: LanguageToolMatch, fullText: String) -> Bool {
        let endOffset = match.offset + match.length
        guard endOffset < fullText.count else { return false }
        let nsText = fullText as NSString
        // Check if there's an apostrophe (or typographic quote) right after the flagged word
        let remainingStart = endOffset
        let remainingLength = min(nsText.length - remainingStart, 10)
        guard remainingLength > 0 else { return false }
        let after = nsText.substring(with: NSRange(location: remainingStart, length: remainingLength))
        guard let first = after.first, first == "'" || first == "\u{2019}" || first == "\u{2018}" else {
            return false
        }
        // Build what the full word would be: flaggedWord + rest up to next space/punctuation
        var suffix = ""
        for ch in after {
            if ch.isWhitespace || (ch.isPunctuation && ch != "'" && ch != "\u{2019}" && ch != "\u{2018}") {
                break
            }
            suffix.append(ch)
        }
        let reconstructed = flaggedWord + suffix
        // If any replacement matches the reconstructed word, it's a false positive
        return match.replacements.contains { $0.value.lowercased() == reconstructed.lowercased() }
    }

    private func defaultSeverity(for match: LanguageToolMatch) -> IssueSeverity {
        let categoryID = match.rule.category?.id ?? ""
        // Spelling and grammar issues are warnings; style suggestions are info
        switch categoryID {
        case "TYPOS", "GRAMMAR", "PUNCTUATION":
            return .warning
        default:
            return .info
        }
    }
}
