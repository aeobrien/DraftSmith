import Foundation
import SwiftData

@Model
final class PromptTemplate {
    var id: UUID
    var task: String // PromptTask.rawValue
    var version: Int
    var systemDirective: String
    var taskTemplate: String
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        task: PromptTask,
        version: Int = 1,
        systemDirective: String,
        taskTemplate: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.task = task.rawValue
        self.version = version
        self.systemDirective = systemDirective
        self.taskTemplate = taskTemplate
        self.isActive = isActive
        self.createdAt = Date()
    }

    var promptTask: PromptTask {
        get { PromptTask(rawValue: task) ?? .diplomaticComment }
        set { task = newValue.rawValue }
    }
}
