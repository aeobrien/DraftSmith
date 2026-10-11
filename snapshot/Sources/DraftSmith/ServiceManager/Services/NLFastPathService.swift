import Foundation
import AppKit

struct FastPathIssue: Sendable, Identifiable {
    let id = UUID()
    let word: String
    let offset: Int
    let length: Int
    let suggestions: [String]
}

@MainActor
final class NLFastPathService {
    private let spellChecker = NSSpellChecker.shared

    func checkSpelling(text: String) -> [FastPathIssue] {
        var issues: [FastPathIssue] = []
        var searchRange = NSRange(location: 0, length: (text as NSString).length)

        while searchRange.location < (text as NSString).length {
            let misspelledRange = spellChecker.checkSpelling(
                of: text,
                startingAt: searchRange.location,
                language: "en_GB",
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )

            guard misspelledRange.location != NSNotFound else { break }

            let word = (text as NSString).substring(with: misspelledRange)
            let guesses = spellChecker.guesses(
                forWordRange: misspelledRange,
                in: text,
                language: "en_GB",
                inSpellDocumentWithTag: 0
            ) ?? []

            issues.append(FastPathIssue(
                word: word,
                offset: misspelledRange.location,
                length: misspelledRange.length,
                suggestions: guesses
            ))

            searchRange.location = misspelledRange.location + misspelledRange.length
        }

        return issues
    }
}
