import Foundation

enum AnnotationSource: String, Codable, Sendable {
    case manual
    case languageTool
    case llmRewrite
    case voiceNote
}

struct AnnotationMetadata: Codable, Sendable, Equatable {
    let dsUUID: UUID
    let createdAt: Date
    let source: AnnotationSource

    init(dsUUID: UUID = UUID(), createdAt: Date = Date(), source: AnnotationSource = .manual) {
        self.dsUUID = dsUUID
        self.createdAt = createdAt
        self.source = source
    }
}
