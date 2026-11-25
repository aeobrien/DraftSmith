import Foundation

actor MockTranscriptionService: ManagedServiceProtocol {
    let kind: ServiceKind = .whisper
    private(set) var state: ServiceState = .ready

    var mockTranscription: String = "This is a mock transcription."

    func start() async throws {
        state = .ready
    }

    func stop() async {
        state = .idle
    }

    func healthCheck() async -> Bool {
        return true
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        return TranscriptionResult(
            text: mockTranscription,
            segments: [TranscriptionSegment(text: mockTranscription, start: 0, end: 5)],
            language: "en",
            duration: 5
        )
    }
}
