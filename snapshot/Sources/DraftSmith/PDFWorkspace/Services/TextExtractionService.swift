import Foundation
import NaturalLanguage
import PDFKit

enum ExtractionConfidence: Sendable {
    case high
    case low
    case unreadable
}

struct ExtractionResult: Sendable {
    let text: String
    let confidence: ExtractionConfidence
    let nonDictionaryRatio: Double
}

@MainActor
final class TextExtractionService {
    private let recognizer = NLLanguageRecognizer()
    private static let nonDictionaryThresholdLow = 0.3
    private static let nonDictionaryThresholdUnreadable = 0.6

    func extractText(from selection: PDFSelection) -> ExtractionResult {
        let text = selection.string ?? ""
        guard !text.isEmpty else {
            return ExtractionResult(text: "", confidence: .unreadable, nonDictionaryRatio: 1.0)
        }

        let ratio = computeNonDictionaryRatio(text)
        let confidence: ExtractionConfidence
        if ratio >= Self.nonDictionaryThresholdUnreadable {
            confidence = .unreadable
        } else if ratio >= Self.nonDictionaryThresholdLow {
            confidence = .low
        } else {
            confidence = .high
        }

        return ExtractionResult(text: text, confidence: confidence, nonDictionaryRatio: ratio)
    }

    private func computeNonDictionaryRatio(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text

        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        guard !words.isEmpty else { return 0 }

        let checker = NSSpellChecker.shared
        var nonDictionaryCount = 0

        for word in words {
            let wordString = String(word)
            // Skip very short words and numbers
            if wordString.count <= 2 || wordString.allSatisfy(\.isNumber) {
                continue
            }
            let range = checker.checkSpelling(
                of: wordString,
                startingAt: 0,
                language: "en",
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            if range.location != NSNotFound {
                nonDictionaryCount += 1
            }
        }

        let checkableWords = words.filter { word in
            let s = String(word)
            return s.count > 2 && !s.allSatisfy(\.isNumber)
        }
        guard !checkableWords.isEmpty else { return 0 }

        return Double(nonDictionaryCount) / Double(checkableWords.count)
    }
}
