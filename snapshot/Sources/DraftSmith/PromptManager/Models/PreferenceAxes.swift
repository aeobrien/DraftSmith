import Foundation

struct PreferenceAxes: Codable, Sendable, Equatable {
    /// 0.0 = gentle, 1.0 = direct
    var directness: Double
    /// 0.0 = brief, 1.0 = thorough
    var brevity: Double
    /// 0.0 = formal, 1.0 = warm
    var formality: Double
    /// 0.0 = comment only, 1.0 = suggest rewrite
    var rewriteVsComment: Double

    static let `default` = PreferenceAxes(
        directness: 0.5,
        brevity: 0.5,
        formality: 0.5,
        rewriteVsComment: 0.0
    )

    var asPromptFragment: String {
        """
        Preference axes (0.0-1.0 scale):
        - Directness: \(String(format: "%.1f", directness)) (\(directnessLabel))
        - Brevity: \(String(format: "%.1f", brevity)) (\(brevityLabel))
        - Formality: \(String(format: "%.1f", formality)) (\(formalityLabel))
        - Rewrite vs Comment: \(String(format: "%.1f", rewriteVsComment)) (\(rewriteLabel))
        """
    }

    private var directnessLabel: String {
        if directness < 0.3 { return "very gentle" }
        if directness < 0.7 { return "neutral" }
        return "direct"
    }

    private var brevityLabel: String {
        if brevity < 0.3 { return "brief" }
        if brevity < 0.7 { return "moderate" }
        return "thorough"
    }

    private var formalityLabel: String {
        if formality < 0.3 { return "formal" }
        if formality < 0.7 { return "neutral" }
        return "warm"
    }

    private var rewriteLabel: String {
        if rewriteVsComment < 0.3 { return "comment only" }
        if rewriteVsComment < 0.7 { return "mixed" }
        return "suggest rewrite"
    }
}
