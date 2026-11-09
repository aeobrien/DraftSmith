import Foundation

enum VoiceNotePipelineState: Equatable {
    case idle
    case recording
    case transcribing
    case editingTranscript
    case generatingVariants
    case complete
}

@Observable
@MainActor
final class VoiceNotePipeline {
    private(set) var state: VoiceNotePipelineState = .idle
    private(set) var transcriptText: String = ""
    private(set) var transcriptionStatus: String = "Transcribing..."
    private(set) var variants: [CommentVariant] = []
    private(set) var currentRecording: AudioRecording?
    private(set) var currentAnnotationUUID: UUID?

    let audioRecorder: AudioRecorder
    private let serviceManager: ServiceManager
    private let rewriteEngine: RewriteEngine
    private let transcriptStore = TranscriptStore()

    init(
        audioRecorder: AudioRecorder,
        serviceManager: ServiceManager,
        rewriteEngine: RewriteEngine
    ) {
        self.audioRecorder = audioRecorder
        self.serviceManager = serviceManager
        self.rewriteEngine = rewriteEngine
    }

    func startRecording(annotationUUID: UUID, passage: String) throws {
        currentAnnotationUUID = annotationUUID
        try audioRecorder.startRecording(annotationUUID: annotationUUID)
        state = .recording
    }

    func stopRecording() async {
        guard let recording = audioRecorder.stopRecording() else {
            state = .idle
            return
        }
        currentRecording = recording
        state = .transcribing

        // Ensure Whisper is loaded (can take 30s+ on first use)
        transcriptionStatus = "Loading speech recognition model..."
        await serviceManager.ensureReady(.whisper)

        transcriptionStatus = "Transcribing audio..."
        do {
            let result = try await serviceManager.transcriptionService.transcribe(audioURL: recording.url)
            if result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                transcriptText = "(No speech detected — try recording again)"
            } else {
                transcriptText = result.text
            }
            state = .editingTranscript
        } catch {
            transcriptText = "(Transcription failed: \(error.localizedDescription))"
            state = .editingTranscript
        }
    }

    func confirmTranscript(editedText: String, passage: String, axes: PreferenceAxes) async {
        transcriptText = editedText
        state = .generatingVariants

        // Save transcript
        if let uuid = currentAnnotationUUID {
            try? transcriptStore.save(text: editedText, annotationUUID: uuid)
        }

        // Generate variants
        do {
            variants = try await rewriteEngine.generateCommentVariants(
                passage: passage,
                transcript: editedText,
                axes: axes
            )
            state = .complete
        } catch {
            state = .editingTranscript
        }
    }

    func cancel() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        reset()
    }

    func reset() {
        state = .idle
        transcriptText = ""
        transcriptionStatus = "Transcribing..."
        variants = []
        currentRecording = nil
        currentAnnotationUUID = nil
    }
}
