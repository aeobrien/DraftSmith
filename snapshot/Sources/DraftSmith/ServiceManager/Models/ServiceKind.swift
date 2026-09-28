import Foundation

enum ServiceKind: String, CaseIterable, Sendable, Identifiable {
    case languageTool
    case llm
    case whisper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .languageTool: return "Grammar Engine"
        case .llm: return "Rewrite Engine"
        case .whisper: return "Transcription"
        }
    }

    var statusDescription: String {
        switch self {
        case .languageTool: return "Grammar engine starting..."
        case .llm: return "Rewrite engine loading..."
        case .whisper: return "Transcription starting..."
        }
    }
}
