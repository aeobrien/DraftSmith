import Foundation

enum PromptTask: String, CaseIterable, Sendable, Codable, Identifiable {
    case diplomaticComment = "diplomatic_comment"
    case rewriteSuggestion = "rewrite_suggestion"
    case emailDraft = "email_draft"
    case styleCapsuleGeneration = "style_capsule_generation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diplomaticComment: return "Diplomatic Comment"
        case .rewriteSuggestion: return "Rewrite Suggestion"
        case .emailDraft: return "Email Draft"
        case .styleCapsuleGeneration: return "Style Capsule"
        }
    }

    var description: String {
        switch self {
        case .diplomaticComment:
            return "Generate diplomatic editorial comment variants from a voice note transcript or manual input"
        case .rewriteSuggestion:
            return "Generate rewrite suggestions for a flagged passage"
        case .emailDraft:
            return "Draft professional emails using context from the review session"
        case .styleCapsuleGeneration:
            return "Summarise editing tendencies from example pairs and feedback events"
        }
    }
}
