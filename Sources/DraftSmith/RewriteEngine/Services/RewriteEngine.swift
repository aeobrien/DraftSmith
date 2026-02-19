import Foundation

@Observable
@MainActor
final class RewriteEngine: RewriteEngineProtocol {
    private let serviceManager: ServiceManager
    private let promptManager: PromptManagerService
    private let styleMemoryManager: StyleMemoryManager
    private let doubleCheckPipeline: DoubleCheckPipeline
    private let parser = LLMResponseParser()

    private(set) var isGenerating = false
    private(set) var lastPassage: String?
    private(set) var lastTranscript: String?

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

    func generateCommentVariants(
        passage: String,
        transcript: String,
        axes: PreferenceAxes
    ) async throws -> [CommentVariant] {
        isGenerating = true
        defer { isGenerating = false }

        lastPassage = passage
        lastTranscript = transcript

        await serviceManager.ensureReady(.llm)

        let examples = styleMemoryManager.selectExamples(for: .diplomaticComment)
        let capsule = styleMemoryManager.activeCapsuleText

        let assembled = try promptManager.assemblePrompt(
            task: .diplomaticComment,
            placeholders: [
                "passage": passage,
                "transcript": transcript
            ],
            styleCapsule: capsule,
            preferenceAxes: axes,
            examples: examples
        )

        let llmOutput = try await serviceManager.llmService.generate(
            prompt: assembled.userPrompt,
            systemPrompt: assembled.systemPrompt
        )

        let response = try parser.parse(llmOutput, as: CommentGenerationResponse.self)

        // Double-check variants
        let validatedVariants = await doubleCheckPipeline.validateCommentVariants(response.variants)

        return validatedVariants
    }

    func generateRewriteVariants(
        passage: String,
        issue: Issue,
        axes: PreferenceAxes
    ) async throws -> [RewriteVariant] {
        isGenerating = true
        defer { isGenerating = false }

        await serviceManager.ensureReady(.llm)

        let examples = styleMemoryManager.selectExamples(for: .rewriteSuggestion)
        let capsule = styleMemoryManager.activeCapsuleText

        let assembled = try promptManager.assemblePrompt(
            task: .rewriteSuggestion,
            placeholders: [
                "passage": passage,
                "issue_description": issue.message
            ],
            styleCapsule: capsule,
            preferenceAxes: axes,
            examples: examples
        )

        let llmOutput = try await serviceManager.llmService.generate(
            prompt: assembled.userPrompt,
            systemPrompt: assembled.systemPrompt
        )

        let response = try parser.parse(llmOutput, as: RewriteResponse.self)

        return response.variants
    }

    func rewriteComment(
        commentText: String,
        direction: CommentRewriteDirection
    ) async throws -> [CommentVariant] {
        isGenerating = true
        defer { isGenerating = false }

        await serviceManager.ensureReady(.llm)

        let capsule = styleMemoryManager.activeCapsuleText

        let systemPrompt = """
        You are a British editorial assistant. Use British English spelling. \
        Respond with valid JSON only.
        """

        var capsuleBlock = ""
        if !capsule.isEmpty {
            capsuleBlock = "\nSTYLE CAPSULE:\n\(capsule)\n"
        }

        let userPrompt = """
        \(direction.promptInstruction)
        \(capsuleBlock)
        Rewrite the following comment.

        COMMENT: \(commentText)

        JSON format: {"variants":[{"id":"v1","label":"...","axes":{"directness":0.0,"brevity":0.0,"formality":0.0,"rewrite_vs_comment":0.0},"text":"..."}],"notes_for_user":""}
        """

        let llmOutput = try await serviceManager.llmService.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 2000
        )

        let response = try parser.parse(llmOutput, as: CommentGenerationResponse.self)

        return response.variants
    }

    func regenerate(
        currentVariants: [CommentVariant],
        axes: PreferenceAxes,
        adjustedAxis: String?
    ) async throws -> [CommentVariant] {
        guard let passage = lastPassage else {
            throw DraftSmithError.llmGenerationFailed("No previous passage to regenerate from")
        }

        return try await generateCommentVariants(
            passage: passage,
            transcript: lastTranscript ?? "",
            axes: axes
        )
    }

    func generateIssueComment(
        category: String,
        ruleID: String?,
        flaggedText: String,
        suggestion: String,
        message: String,
        exampleComments: [String]
    ) async throws -> String {
        await serviceManager.ensureReady(.llm)

        let categoryLower = category.lowercased()
        var tone: String
        if categoryLower.contains("typo") || (ruleID ?? "").contains("MORFOLOGIK") {
            tone = "a possible misspelling"
        } else if categoryLower.contains("style") || categoryLower.contains("redundancy") {
            tone = "a style suggestion"
        } else if (ruleID ?? "").contains("EN_GB") || (ruleID ?? "").contains("EN_US") {
            tone = "a British/American English spelling difference"
        } else {
            tone = "a grammar or usage issue"
        }

        let capsule = styleMemoryManager.activeCapsuleText
        var capsuleBlock = ""
        if !capsule.isEmpty {
            capsuleBlock = "\nSTYLE CAPSULE (follow these editorial preferences):\n\(capsule)\n"
        }

        var examplesBlock = ""
        if !exampleComments.isEmpty {
            let numbered = exampleComments.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            examplesBlock = """

            EXAMPLE COMMENTS FOR THIS CATEGORY (match this style and tone):
            \(numbered)

            """
        }

        let systemPrompt = """
        You are a British editorial assistant writing margin comments on a manuscript. \
        Use British English spelling. Do NOT use <think> tags or any internal reasoning. \
        Respond with ONLY the comment text — no JSON, no quotation marks, no greetings, \
        no sign-offs. Write as a brief professional margin note, not a message.
        """

        let userPrompt = """
        Write a 1–2 sentence margin comment about \(tone).
        \(capsuleBlock)\(examplesBlock)
        Flagged text: "\(flaggedText)"
        Suggested replacement: "\(suggestion)"
        Issue: \(message)

        Write a brief, professional margin note — the kind an editor leaves in the \
        margin of a manuscript. No greetings, no sign-offs, just the editorial observation. \
        Write a complete sentence, not a terse label. Respond immediately with the comment.
        """

        let output = try await serviceManager.llmService.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 2000
        )

        print("[LLM] generateIssueComment raw output (\(output.count) chars): \"\(output.prefix(200))\"")

        let result = Self.stripThinkingTags(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        print("[LLM] generateIssueComment after strip (\(result.count) chars): \"\(result.prefix(200))\"")
        return result
    }

    /// Polishes a comment using a simpler plain-text response (no JSON required).
    /// Used for background suggestions where the full CommentGenerationResponse structure
    /// is too complex for the model to produce reliably.
    func polishComment(commentText: String) async throws -> String {
        await serviceManager.ensureReady(.llm)

        let capsule = styleMemoryManager.activeCapsuleText
        var capsuleBlock = ""
        if !capsule.isEmpty {
            capsuleBlock = "\nSTYLE CAPSULE:\n\(capsule)\n"
        }

        let systemPrompt = """
        You are a British editorial assistant. Use British English spelling. \
        Do NOT use <think> tags or any internal reasoning. \
        Respond with ONLY the polished comment text — no JSON, no quotation marks, \
        no preamble, no explanation. Just the improved text.
        """

        let userPrompt = """
        Rewrite this editorial margin comment to be clearer, more professional, \
        and more diplomatically phrased. Keep it concise (1–3 sentences). \
        Respond immediately with only the rewritten text, nothing else.
        \(capsuleBlock)
        ORIGINAL COMMENT: \(commentText)

        REWRITTEN COMMENT:
        """

        let output = try await serviceManager.llmService.generate(
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 2000
        )

        print("[REWRITE] Raw LLM output for polishComment: \"\(output.prefix(200))\"")

        let result = Self.stripThinkingTags(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard !result.isEmpty else {
            throw DraftSmithError.llmGenerationFailed("Empty response from polishComment after stripping (raw length: \(output.count))")
        }
        return result
    }

    /// Strips `<think>...</think>` blocks that some models emit for chain-of-thought.
    private static func stripThinkingTags(from text: String) -> String {
        var result = text
        while let startRange = result.range(of: "<think>", options: .caseInsensitive) {
            if let endRange = result.range(of: "</think>", options: .caseInsensitive, range: startRange.upperBound..<result.endIndex) {
                result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            } else {
                // Unclosed <think> tag — remove everything from <think> onward
                result.removeSubrange(startRange.lowerBound..<result.endIndex)
            }
        }
        return result
    }
}
