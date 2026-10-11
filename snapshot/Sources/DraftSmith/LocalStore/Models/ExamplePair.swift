import Foundation
import SwiftData

@Model
final class ExamplePair {
    var id: UUID
    var inputText: String
    var outputText: String
    var category: String // PromptTask.rawValue
    var tokenCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        inputText: String,
        outputText: String,
        category: PromptTask = .diplomaticComment,
        tokenCount: Int = 0
    ) {
        self.id = id
        self.inputText = inputText
        self.outputText = outputText
        self.category = category.rawValue
        self.tokenCount = tokenCount
        self.createdAt = Date()
    }

    var promptTask: PromptTask {
        get { PromptTask(rawValue: category) ?? .diplomaticComment }
        set { category = newValue.rawValue }
    }
}
