import Foundation

enum AppGuide {
    static let text = """
    DraftSmith is a PDF proofreading assistant for macOS. It helps users review PDF documents \
    for grammar, style, and spelling issues, and add review comments directly onto the PDF.

    MAIN INTERFACE
    The app has three main areas:
    - Centre: The PDF viewer showing the document being reviewed.
    - Right sidebar: The comment panel listing all annotations/comments on the PDF.
    - Bottom bar: The issue bar showing detected issues with inline actions.

    PDF VIEWER
    - Displays the currently open PDF document.
    - Users can select text in the PDF to check it or add comments.
    - A status bar at the bottom shows review progress and service status.
    - Inline markers (red underlines) can be toggled on to highlight flagged text directly in the PDF.
    - Clicking an inline marker opens a popover with quick actions for that issue.

    ISSUES
    Issues are problems detected in the document text. They come from LanguageTool, a grammar and \
    style checking engine that runs locally. Each issue has:
    - A message describing the problem (e.g. "Possible spelling mistake found").
    - The flagged text that triggered the issue.
    - A severity level: Warning (orange triangle) or Info (blue circle).
    - A status: New (unreviewed), Resolved (addressed), or Dismissed (ignored).
    - One or more suggestions for how to fix the issue.
    - A category (e.g. "Grammar", "Typos", "Style").

    ISSUE BAR (Bottom)
    - Shows a filterable list of issues on the left and issue details on the right.
    - Filter by status (New, Resolved, Dismissed, All) and by category.
    - Navigate between issues using the up/down arrow keys.
    - Keyboard shortcuts: D = dismiss, R = resolve, Q = quick comment, N = natural comment.
    - Each suggestion offers three actions:
      - Quick: Adds a structured comment like "Grammar: suggested text".
      - Natural: Uses AI to generate a conversational comment explaining the issue.
      - Edit: Generates a comment and opens an editor to modify it before adding.
    - The "..." menu offers: dismiss all matching text, dismiss all from same rule, add to dictionary.

    COMMENTS / ANNOTATIONS
    - Comments are highlights on the PDF with attached text notes.
    - They appear as yellow highlights in the PDF and are listed in the right sidebar.
    - Users can add comments manually, via voice recording, or from issue suggestions.
    - Comments can be rewritten using AI to adjust tone (softer, firmer, more polished).
    - The sidebar shows a suggestion badge when AI has generated a rewrite suggestion.

    INLINE MARKERS
    - Toggle on/off using the eye icon in the status bar at the bottom.
    - When enabled, red underlines appear on flagged text in the PDF.
    - Clicking an underline opens a popover with the issue details and quick actions.
    - Actions in the popover work the same as in the issue bar.

    REVIEW WORKFLOW
    1. Open a PDF document using the toolbar button or File menu.
    2. Click "Check Document" to scan the entire document for issues.
    3. Review issues in the bottom bar, navigating with arrow keys.
    4. For each issue: dismiss it, resolve it, or add a comment with a suggestion.
    5. Optionally toggle inline markers to see issues highlighted in the PDF.
    6. Save the PDF when done (Cmd+S or toolbar button).

    VOICE RECORDING
    - Press the V key while text is selected to start a quick voice recording.
    - Press V again to stop; the recording is transcribed and added as a comment.
    - The microphone button in the toolbar opens a voice note panel for longer recordings.

    SETTINGS
    - Project profiles: Configure language, picky mode, and custom dictionaries.
    - Custom dictionary: Words added here won't be flagged as spelling errors.
    - Picky mode: When enabled, LanguageTool applies stricter rules.

    SERVICE STATUS
    - The status bar shows the health of background services.
    - LanguageTool (grammar checking) runs as a local HTTP service.
    - The LLM (language model) runs locally for generating comments and rewrites.
    - WhisperKit handles speech-to-text transcription for voice notes.
    """
}
