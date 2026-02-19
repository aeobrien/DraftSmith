import Foundation

struct TranscriptionSegment: Sendable, Codable, Identifiable {
    var id: String { "\(start)-\(end)" }
    let text: String
    let start: Float
    let end: Float
}

struct TranscriptionResult: Sendable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
    let duration: Float
}
