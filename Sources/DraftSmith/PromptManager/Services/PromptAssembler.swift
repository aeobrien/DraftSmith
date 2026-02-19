import Foundation

struct AssembledPrompt: Sendable {
    let systemPrompt: String
    let userPrompt: String
    let totalTokenEstimate: Int
    let trimReport: String
}

struct PromptAssembler: Sendable {
    private let tokenCounter = TokenCounter()

    func assemble(
        template: PromptTemplate,
        placeholders: [String: String],
        styleGuide: String = "",
        styleCapsule: String = "",
        preferenceAxes: PreferenceAxes = .default,
        examples: [ExamplePair] = [],
        budget: TokenBudget = .default
    ) -> AssembledPrompt {
        let effectiveBudget = budget.trimmed(availableTokens: AppConstants.TokenBudget.total)

        // Build components
        let systemPrompt = template.systemDirective

        // Build examples text (trimmed to budget)
        let examplesText = buildExamplesText(examples, budget: effectiveBudget.examples)

        // Build style guide (trimmed to budget)
        let guideText = tokenCounter.trim(styleGuide, toFit: effectiveBudget.guide)

        // Build capsule (trimmed to budget)
        let capsuleText = tokenCounter.trim(styleCapsule, toFit: effectiveBudget.capsule)

        // Substitute placeholders
        var userPrompt = template.taskTemplate
        var allPlaceholders = placeholders
        allPlaceholders["style_guide"] = guideText.isEmpty ? "(No style guide active)" : guideText
        allPlaceholders["style_capsule"] = capsuleText.isEmpty ? "(No style capsule active)" : capsuleText
        allPlaceholders["preference_axes"] = preferenceAxes.asPromptFragment
        allPlaceholders["examples"] = examplesText.isEmpty ? "(No examples provided)" : examplesText
        allPlaceholders["variant_count"] = "\(AppConstants.defaultVariantCount)"
        allPlaceholders["max_tokens"] = "\(AppConstants.capsuleMaxTokens)"

        for (key, value) in allPlaceholders {
            userPrompt = userPrompt.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        // Calculate tokens
        let systemTokens = tokenCounter.countTokens(systemPrompt)
        let userTokens = tokenCounter.countTokens(userPrompt)
        let totalTokens = systemTokens + userTokens

        // Build trim report
        var trimNotes: [String] = []
        if effectiveBudget.examples < budget.examples {
            trimNotes.append("Examples trimmed from \(budget.examples) to \(effectiveBudget.examples) tokens")
        }
        if effectiveBudget.guide < budget.guide {
            trimNotes.append("Style guide trimmed from \(budget.guide) to \(effectiveBudget.guide) tokens")
        }
        if effectiveBudget.capsule < budget.capsule {
            trimNotes.append("Capsule trimmed from \(budget.capsule) to \(effectiveBudget.capsule) tokens")
        }
        let trimReport = trimNotes.isEmpty ? "No trimming required" : trimNotes.joined(separator: "; ")

        return AssembledPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            totalTokenEstimate: totalTokens,
            trimReport: trimReport
        )
    }

    // MARK: - Private

    private func buildExamplesText(_ examples: [ExamplePair], budget: Int) -> String {
        guard !examples.isEmpty else { return "" }

        var text = ""
        var usedTokens = 0

        for example in examples {
            let exampleText = """
            Input: \(example.inputText)
            Output: \(example.outputText)

            """
            let tokens = tokenCounter.countTokens(exampleText)
            if usedTokens + tokens > budget { break }
            text += exampleText
            usedTokens += tokens
        }

        return text
    }
}
