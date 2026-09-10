import Foundation

struct TokenBudget: Sendable {
    let system: Int
    let guide: Int
    let capsule: Int
    let examples: Int
    let input: Int
    let output: Int
    let metadata: Int

    static let `default` = TokenBudget(
        system: AppConstants.TokenBudget.system,
        guide: AppConstants.TokenBudget.guide,
        capsule: AppConstants.TokenBudget.capsule,
        examples: AppConstants.TokenBudget.examples,
        input: AppConstants.TokenBudget.input,
        output: AppConstants.TokenBudget.output,
        metadata: 100
    )

    var totalBudget: Int {
        system + guide + capsule + examples + input + output + metadata
    }

    var inputBudget: Int {
        totalBudget - output
    }

    /// Returns a trimmed budget when the total exceeds the context window.
    /// Trim priority: examples first, then guide, then capsule.
    /// Input and output are never trimmed.
    func trimmed(availableTokens: Int) -> TokenBudget {
        let needed = system + guide + capsule + examples + input + output + metadata
        guard needed > availableTokens else { return self }

        let excess = needed - availableTokens
        var examplesReduced = examples
        var guideReduced = guide
        var capsuleReduced = capsule

        var remaining = excess

        // Trim examples first
        let examplesTrim = min(remaining, examples - 0)
        examplesReduced -= examplesTrim
        remaining -= examplesTrim

        // Trim guide second
        if remaining > 0 {
            let guideTrim = min(remaining, guide)
            guideReduced -= guideTrim
            remaining -= guideTrim
        }

        // Trim capsule third
        if remaining > 0 {
            let capsuleTrim = min(remaining, capsule)
            capsuleReduced -= capsuleTrim
            remaining -= capsuleTrim
        }

        return TokenBudget(
            system: system,
            guide: guideReduced,
            capsule: capsuleReduced,
            examples: examplesReduced,
            input: input,
            output: output,
            metadata: metadata
        )
    }
}
