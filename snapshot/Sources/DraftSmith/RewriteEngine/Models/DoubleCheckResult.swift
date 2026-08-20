import Foundation

struct SpellingCorrection: Sendable, Equatable {
    let original: String
    let corrected: String
    let ruleID: String
}

struct StyleFlag: Sendable, Equatable, Identifiable {
    let id = UUID()
    let message: String
    let ruleID: String
    let severity: DoubleCheckSeverity
}

enum DoubleCheckSeverity: Sendable, Equatable {
    case clean
    case minorFlags
    case significantFlags

    var shouldRegenerate: Bool {
        self == .significantFlags
    }
}

struct DoubleCheckResult: Sendable {
    let correctedText: String
    let spellingCorrections: [SpellingCorrection]
    let styleFlags: [StyleFlag]
    let severity: DoubleCheckSeverity
}
