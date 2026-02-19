import Foundation

struct LanguageToolResponse: Codable, Sendable {
    let software: LanguageToolSoftware?
    let language: LanguageToolLanguageInfo?
    let matches: [LanguageToolMatch]
}

struct LanguageToolSoftware: Codable, Sendable {
    let name: String?
    let version: String?
    let buildDate: String?
    let apiVersion: Int?
}

struct LanguageToolLanguageInfo: Codable, Sendable {
    let name: String?
    let code: String?
    let detectedLanguage: DetectedLanguage?
}

struct DetectedLanguage: Codable, Sendable {
    let name: String?
    let code: String?
    let confidence: Double?
}

struct LanguageToolMatch: Codable, Sendable, Identifiable {
    let message: String
    let shortMessage: String?
    let offset: Int
    let length: Int
    let replacements: [LanguageToolReplacement]
    let rule: LanguageToolRule
    let context: LanguageToolContext?
    let sentence: String?

    var id: String {
        "\(rule.id)_\(offset)_\(length)"
    }
}

struct LanguageToolReplacement: Codable, Sendable {
    let value: String
}

struct LanguageToolRule: Codable, Sendable {
    let id: String
    let description: String?
    let category: LanguageToolCategory?
    let issueType: String?
}

struct LanguageToolCategory: Codable, Sendable {
    let id: String
    let name: String
}

struct LanguageToolContext: Codable, Sendable {
    let text: String
    let offset: Int
    let length: Int
}
