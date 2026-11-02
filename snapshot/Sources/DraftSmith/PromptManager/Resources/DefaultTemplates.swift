import Foundation

enum DefaultTemplates {
    static let systemDirective = """
    You are a British editorial assistant. You strictly use British English spelling conventions \
    (e.g. "organise" not "organize", "colour" not "color", "analyse" not "analyze"). \
    You produce clean, professional editorial feedback. You always respond with valid JSON only.
    """

    static let diplomaticComment = """
    Given the following passage from a document and a voice note transcript (or editorial observation), \
    generate {{variant_count}} comment variants that the editor could attach to this passage as a PDF annotation.

    Each variant should represent a genuinely different approach along the preference axes provided. \
    Vary the tone, directness, and length meaningfully between variants.

    {{style_guide}}
    {{style_capsule}}
    {{preference_axes}}
    {{examples}}

    PASSAGE:
    {{passage}}

    TRANSCRIPT/OBSERVATION:
    {{transcript}}

    Respond with valid JSON in this exact format:
    {
      "variants": [
        {
          "id": "v1",
          "label": "descriptive label",
          "axes": { "directness": 0.0, "brevity": 0.0, "formality": 0.0, "rewrite_vs_comment": 0.0 },
          "text": "the comment text"
        }
      ],
      "notes_for_user": ""
    }
    """

    static let rewriteSuggestion = """
    Given the following passage that has been flagged with a grammar/style issue, \
    generate {{variant_count}} rewrite suggestions.

    Each variant should fix the identified issue while varying in approach (minimal fix vs smoother rewrite vs publisher-safe).

    {{style_guide}}
    {{style_capsule}}
    {{preference_axes}}
    {{examples}}

    PASSAGE:
    {{passage}}

    ISSUE:
    {{issue_description}}

    Respond with valid JSON in this exact format:
    {
      "variants": [
        {
          "id": "r1",
          "label": "descriptive label",
          "axes": { "directness": 0.0, "brevity": 0.0, "formality": 0.0, "rewrite_vs_comment": 1.0 },
          "text": "the rewritten text",
          "diff_summary": "brief description of changes"
        }
      ]
    }
    """

    static let emailDraft = """
    Draft {{variant_count}} professional email variants based on the following context.

    Each variant should represent a genuinely different approach along the preference axes provided.

    {{style_guide}}
    {{style_capsule}}
    {{preference_axes}}
    {{examples}}

    RECIPIENT CONTEXT:
    {{recipient_context}}

    GOAL:
    {{goal}}

    KEY FACTS:
    {{key_facts}}

    Respond with valid JSON in this exact format:
    {
      "subject_options": ["subject line 1", "subject line 2"],
      "drafts": [
        {
          "id": "e1",
          "label": "descriptive label",
          "axes": { "directness": 0.0, "brevity": 0.0, "formality": 0.0, "rewrite_vs_comment": 0.0 },
          "body": "the email body text"
        }
      ]
    }
    """

    static let styleCapsuleGeneration = """
    Analyse the following example pairs and feedback events to generate a concise Style Capsule \
    — a natural-language summary of this editor's tendencies and preferences.

    The capsule must be under {{max_tokens}} tokens. Focus on:
    - Preferred tone and register
    - Common editing patterns (brevity preference, hedging removal, etc.)
    - Terminology preferences
    - Any consistent style choices

    EXAMPLE PAIRS:
    {{example_pairs}}

    FEEDBACK EVENTS:
    {{feedback_events}}

    Respond with valid JSON in this exact format:
    {
      "capsule_text": "the capsule summary text",
      "key_tendencies": ["tendency 1", "tendency 2"],
      "token_count": 0
    }
    """

    static func template(for task: PromptTask) -> (systemDirective: String, taskTemplate: String) {
        switch task {
        case .diplomaticComment:
            return (systemDirective, diplomaticComment)
        case .rewriteSuggestion:
            return (systemDirective, rewriteSuggestion)
        case .emailDraft:
            return (systemDirective, emailDraft)
        case .styleCapsuleGeneration:
            return (systemDirective, styleCapsuleGeneration)
        }
    }
}
