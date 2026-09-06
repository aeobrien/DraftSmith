import Foundation

// Section 11.1 — Diplomatic Comment Generation
struct CommentGenerationResponse: Codable, Sendable {
    let variants: [CommentVariant]
    let notesForUser: String?

    enum CodingKeys: String, CodingKey {
        case variants
        case notesForUser = "notes_for_user"
    }
}

// Section 11.2 — Rewrite Suggestions
struct RewriteResponse: Codable, Sendable {
    let variants: [RewriteVariant]
}

// Section 11.3 — Email Drafts
struct EmailDraftResponse: Codable, Sendable {
    let subjectOptions: [String]
    let drafts: [EmailDraftVariant]

    enum CodingKeys: String, CodingKey {
        case subjectOptions = "subject_options"
        case drafts
    }
}

struct EmailDraftVariant: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let axes: VariantAxes
    let body: String
}

// Section 11.4 — Style Capsule
struct StyleCapsuleResponse: Codable, Sendable {
    let capsuleText: String
    let keyTendencies: [String]
    let tokenCount: Int

    enum CodingKeys: String, CodingKey {
        case capsuleText = "capsule_text"
        case keyTendencies = "key_tendencies"
        case tokenCount = "token_count"
    }
}
