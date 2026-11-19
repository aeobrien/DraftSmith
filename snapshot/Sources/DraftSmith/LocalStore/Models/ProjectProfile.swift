import Foundation
import SwiftData

struct LanguageToolCheckConfig: Sendable {
    var enabledRules: [String] = []
    var disabledRules: [String] = []
    var enabledCategories: [String] = []
    var disabledCategories: [String] = []
    var level: String = "default"
}

@Model
final class ProjectProfile {
    var id: UUID
    var name: String
    var enabledRuleIDs: Data?
    var disabledRuleIDs: Data?
    var customDictionaryData: Data?
    var terminologyData: Data?
    var bannedPhrasesData: Data?
    var severityOverridesData: Data?
    var enabledCategoryIDs: Data?
    var disabledCategoryIDs: Data?
    var commentExamplesData: Data?
    var pickyMode: Bool = true
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Default",
        isDefault: Bool = false,
        pickyMode: Bool = true
    ) {
        self.id = id
        self.name = name
        self.pickyMode = pickyMode
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Accessors

    var enabledRules: [String] {
        get { decodeJSON(enabledRuleIDs) ?? [] }
        set { enabledRuleIDs = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var disabledRules: [String] {
        get { decodeJSON(disabledRuleIDs) ?? [] }
        set { disabledRuleIDs = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var customDictionary: [String] {
        get { decodeJSON(customDictionaryData) ?? [] }
        set { customDictionaryData = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var terminology: [TerminologyEntry] {
        get { decodeJSON(terminologyData) ?? [] }
        set { terminologyData = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var bannedPhrases: [String] {
        get { decodeJSON(bannedPhrasesData) ?? [] }
        set { bannedPhrasesData = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var severityOverrides: [String: String] {
        get { decodeJSON(severityOverridesData) ?? [:] }
        set { severityOverridesData = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var enabledCategories: [String] {
        get { decodeJSON(enabledCategoryIDs) ?? [] }
        set { enabledCategoryIDs = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    var disabledCategories: [String] {
        get { decodeJSON(disabledCategoryIDs) ?? [] }
        set { disabledCategoryIDs = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    /// Per-category example comments. Key = category name (e.g. "Grammar"), Value = array of example sentences.
    var commentExamples: [String: [String]] {
        get { decodeJSON(commentExamplesData) ?? [:] }
        set { commentExamplesData = try? JSONEncoder().encode(newValue); updatedAt = Date() }
    }

    func languageToolConfig() -> LanguageToolCheckConfig {
        LanguageToolCheckConfig(
            enabledRules: enabledRules,
            disabledRules: disabledRules,
            enabledCategories: enabledCategories,
            disabledCategories: disabledCategories,
            level: pickyMode ? "picky" : "default"
        )
    }

    private func decodeJSON<T: Decodable>(_ data: Data?) -> T? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
