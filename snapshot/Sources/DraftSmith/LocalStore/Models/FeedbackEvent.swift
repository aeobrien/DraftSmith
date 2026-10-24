import Foundation
import SwiftData

@Model
final class FeedbackEvent {
    var id: UUID
    var originalSuggestion: String
    var editedFinal: String
    var wordLevelDiff: Data? // JSON-encoded [DiffSegment representation]
    var lengthChangeRatio: Double
    var editDistance: Int
    var editIntentTagsData: Data? // JSON-encoded [String]
    var timestamp: Date

    init(
        id: UUID = UUID(),
        originalSuggestion: String,
        editedFinal: String,
        wordLevelDiff: Data? = nil,
        lengthChangeRatio: Double = 0,
        editDistance: Int = 0,
        editIntentTags: [String] = []
    ) {
        self.id = id
        self.originalSuggestion = originalSuggestion
        self.editedFinal = editedFinal
        self.wordLevelDiff = wordLevelDiff
        self.lengthChangeRatio = lengthChangeRatio
        self.editDistance = editDistance
        self.editIntentTagsData = try? JSONEncoder().encode(editIntentTags)
        self.timestamp = Date()
    }

    var editIntentTags: [String] {
        get {
            guard let data = editIntentTagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            editIntentTagsData = try? JSONEncoder().encode(newValue)
        }
    }
}
