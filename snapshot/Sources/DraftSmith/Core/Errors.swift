import Foundation

enum DraftSmithError: LocalizedError {
    // PDF
    case pdfOpenFailed(URL)
    case pdfSaveFailed(URL)
    case pdfAnnotationCreationFailed
    case pdfSelectionEmpty

    // LanguageTool
    case languageToolNotRunning
    case languageToolStartFailed(String)
    case languageToolRequestFailed(String)
    case languageToolResponseParseFailed

    // LLM
    case llmModelNotLoaded
    case llmLoadFailed(String)
    case llmGenerationFailed(String)
    case llmResponseParseFailed(String)
    case llmTokenBudgetExceeded(needed: Int, available: Int)

    // Transcription
    case transcriptionModelNotLoaded
    case transcriptionFailed(String)

    // Audio
    case audioRecordingFailed(String)
    case audioPermissionDenied
    case audioFileNotFound(URL)

    // Service Manager
    case serviceUnavailable(ServiceKind)
    case serviceStartFailed(ServiceKind, String)
    case healthCheckFailed(ServiceKind)

    // Style Memory
    case capsuleGenerationFailed(String)
    case capsuleTooLarge(tokenCount: Int)
    case examplePairInvalid

    // Prompt
    case templateNotFound(PromptTask)
    case promptAssemblyFailed(String)

    // Project Profile
    case profileNotFound(String)
    case profileSaveFailed

    // General
    case fileOperationFailed(String)
    case unexpectedError(String)

    var errorDescription: String? {
        switch self {
        case .pdfOpenFailed(let url):
            return "Failed to open PDF at \(url.lastPathComponent)"
        case .pdfSaveFailed(let url):
            return "Failed to save PDF to \(url.lastPathComponent)"
        case .pdfAnnotationCreationFailed:
            return "Failed to create PDF annotation"
        case .pdfSelectionEmpty:
            return "No text selected in the PDF"
        case .languageToolNotRunning:
            return "Grammar engine is not running"
        case .languageToolStartFailed(let reason):
            return "Failed to start grammar engine: \(reason)"
        case .languageToolRequestFailed(let reason):
            return "Grammar check failed: \(reason)"
        case .languageToolResponseParseFailed:
            return "Failed to parse grammar check results"
        case .llmModelNotLoaded:
            return "Rewrite engine model is not loaded"
        case .llmLoadFailed(let reason):
            return "Failed to load rewrite engine: \(reason)"
        case .llmGenerationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .llmResponseParseFailed(let reason):
            return "Failed to parse AI response: \(reason)"
        case .llmTokenBudgetExceeded(let needed, let available):
            return "Input too large: needs \(needed) tokens, \(available) available"
        case .transcriptionModelNotLoaded:
            return "Transcription model is not loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .audioRecordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .audioPermissionDenied:
            return "Microphone access denied. Please enable in System Settings."
        case .audioFileNotFound(let url):
            return "Audio file not found: \(url.lastPathComponent)"
        case .serviceUnavailable(let kind):
            return "\(kind.displayName) is not available"
        case .serviceStartFailed(let kind, let reason):
            return "Failed to start \(kind.displayName): \(reason)"
        case .healthCheckFailed(let kind):
            return "\(kind.displayName) health check failed"
        case .capsuleGenerationFailed(let reason):
            return "Style capsule generation failed: \(reason)"
        case .capsuleTooLarge(let tokenCount):
            return "Style capsule too large (\(tokenCount) tokens, max \(AppConstants.capsuleMaxTokens))"
        case .examplePairInvalid:
            return "Example pair is invalid"
        case .templateNotFound(let task):
            return "Prompt template not found for \(task.rawValue)"
        case .promptAssemblyFailed(let reason):
            return "Prompt assembly failed: \(reason)"
        case .profileNotFound(let name):
            return "Project profile '\(name)' not found"
        case .profileSaveFailed:
            return "Failed to save project profile"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        case .unexpectedError(let reason):
            return "Unexpected error: \(reason)"
        }
    }
}
