import SwiftUI
import AVFoundation

struct VoiceDictateButton: View {
    let onTranscription: (String) -> Void

    @Environment(ServiceManager.self) private var serviceManager
    @State private var recorder = AudioRecorder()
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var statusText = ""
    @State private var recordingUUID = UUID()

    var body: some View {
        Button {
            if isRecording {
                stopAndTranscribe()
            } else {
                startRecording()
            }
        } label: {
            if isTranscribing {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
            } else {
                Image(systemName: "mic")
            }
        }
        .disabled(isTranscribing)
        .help(isRecording ? "Stop recording" : isTranscribing ? statusText : "Dictate with voice")
    }

    private func startRecording() {
        recordingUUID = UUID()
        do {
            try recorder.startRecording(annotationUUID: recordingUUID)
            isRecording = true
        } catch {
            // Permission denied or recording failed
        }
    }

    private func stopAndTranscribe() {
        guard let recording = recorder.stopRecording() else {
            isRecording = false
            return
        }
        isRecording = false
        isTranscribing = true
        statusText = "Loading..."

        Task {
            statusText = "Loading model..."
            await serviceManager.ensureReady(.whisper)
            statusText = "Transcribing..."
            do {
                let result = try await serviceManager.transcriptionService.transcribe(audioURL: recording.url)
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    onTranscription(text)
                }
            } catch {
                // Transcription failed
            }
            isTranscribing = false
            statusText = ""
        }
    }
}
