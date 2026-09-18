import Foundation

@Observable
@MainActor
final class EmailStudioService {
    private let serviceManager: ServiceManager
    private let promptManager: PromptManagerService
    private let styleMemoryManager: StyleMemoryManager
    private let doubleCheckPipeline: DoubleCheckPipeline
    private let parser = LLMResponseParser()

    private(set) var isGenerating = false
    private(set) var subjectOptions: [String] = []
    private(set) var drafts: [EmailDraftVariant] = []

    init(
        serviceManager: ServiceManager,
        promptManager: PromptManagerService,
        styleMemoryManager: StyleMemoryManager,
        doubleCheckPipeline: DoubleCheckPipeline
    ) {
        self.serviceManager = serviceManager
        self.promptManager = promptManager
        self.styleMemoryManager = styleMemoryManager
        self.doubleCheckPipeline = doubleCheckPipeline
    }

    func generateDrafts(request: EmailGenerationRequest) async throws {
        isGenerating = true
        defer { isGenerating = false }

        await serviceManager.ensureReady(.llm)

        let examples = styleMemoryManager.selectExamples(for: .emailDraft)
        let capsule = styleMemoryManager.activeCapsuleText

        let assembled = try promptManager.assemblePrompt(
            task: .emailDraft,
            placeholders: [
                "recipient_context": request.recipientContext.isEmpty ? "(No recipient context)" : request.recipientContext,
                "goal": request.goal,
                "key_facts": request.keyFacts.isEmpty ? "(No key facts)" : request.keyFacts
            ],
            styleCapsule: capsule,
            preferenceAxes: request.axes,
            examples: examples
        )

        let llmOutput = try await serviceManager.llmService.generate(
            prompt: assembled.userPrompt,
            systemPrompt: assembled.systemPrompt
        )

        let response = try parser.parse(llmOutput, as: EmailDraftResponse.self)

        subjectOptions = response.subjectOptions
        drafts = await doubleCheckPipeline.validateEmailDrafts(response.drafts)
    }

    func insertIssueContext(issue: Issue) -> String {
        var context = "Issue: \(issue.message)"
        if !issue.selectionText.isEmpty {
            context += "\nFlagged text: \"\(issue.selectionText)\""
        }
        if let category = issue.category {
            context += "\nCategory: \(category)"
        }
        context += "\nPage: \(issue.pageIndex + 1)"
        return context
    }
}
