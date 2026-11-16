import Foundation
import WhisperKit

actor TranscriptionService: ManagedServiceProtocol {
    let kind: ServiceKind = .whisper
    private(set) var state: ServiceState = .idle

    private var whisperKit: WhisperKit?

    func start() async throws {
        guard state.isIdle else { return }
        state = .loading(progress: 0)

        do {
            let config = WhisperKitConfig(model: "base.en")
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw DraftSmithError.transcriptionFailed(error.localizedDescription)
        }
    }

    func stop() async {
        state = .unloading
        whisperKit = nil
        state = .idle
    }

    func healthCheck() async -> Bool {
        return whisperKit != nil && state.isReady
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, state.isReady else {
            throw DraftSmithError.transcriptionModelNotLoaded
        }

        let results = try await whisperKit.transcribe(audioPath: audioURL.path)

        let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        let segments = results.flatMap { result in
            result.segments.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    start: segment.start,
                    end: segment.end
                )
            }
        }

        return TranscriptionResult(
            text: text,
            segments: segments,
            language: "en",
            duration: segments.last?.end ?? 0
        )
    }
}
