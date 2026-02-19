import Foundation

struct AudioRecording: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval
    let annotationUUID: UUID
    let timestamp: Date

    init(url: URL, duration: TimeInterval, annotationUUID: UUID, timestamp: Date = Date()) {
        self.url = url
        self.duration = duration
        self.annotationUUID = annotationUUID
        self.timestamp = timestamp
    }
}
