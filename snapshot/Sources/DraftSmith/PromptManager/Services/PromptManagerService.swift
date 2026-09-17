import Foundation
import SwiftData

@Observable
@MainActor
final class PromptManagerService {
    private let modelContext: ModelContext
    private let assembler = PromptAssembler()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func seedDefaults() {
        for task in PromptTask.allCases {
            let existing = fetchActiveTemplate(for: task)
            if existing == nil {
                let (systemDirective, taskTemplate) = DefaultTemplates.template(for: task)
                let template = PromptTemplate(
                    task: task,
                    systemDirective: systemDirective,
                    taskTemplate: taskTemplate
                )
                modelContext.insert(template)
            }
        }
        try? modelContext.save()
    }

    func fetchActiveTemplate(for task: PromptTask) -> PromptTemplate? {
        let descriptor = FetchDescriptor<PromptTemplate>(
            sortBy: [SortDescriptor(\.version, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.first { $0.task == task.rawValue && $0.isActive }
    }

    func fetchAllTemplates() -> [PromptTemplate] {
        let descriptor = FetchDescriptor<PromptTemplate>(
            sortBy: [SortDescriptor(\.task), SortDescriptor(\.version, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func assemblePrompt(
        task: PromptTask,
        placeholders: [String: String],
        styleGuide: String = "",
        styleCapsule: String = "",
        preferenceAxes: PreferenceAxes = .default,
        examples: [ExamplePair] = []
    ) throws -> AssembledPrompt {
        guard let template = fetchActiveTemplate(for: task) else {
            throw DraftSmithError.templateNotFound(task)
        }

        return assembler.assemble(
            template: template,
            placeholders: placeholders,
            styleGuide: styleGuide,
            styleCapsule: styleCapsule,
            preferenceAxes: preferenceAxes,
            examples: examples
        )
    }
}
