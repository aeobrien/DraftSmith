import SwiftUI

struct VoiceNotePanelView: View {
    @Environment(VoiceNotePipeline.self) private var pipeline
    let passage: String
    let axes: PreferenceAxes
    let onUseAsComment: (CommentVariant) -> Void

    @State private var editableTranscript = ""
    @State private var selectedVariantID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch pipeline.state {
                case .idle:
                    idleView

                case .recording:
                    VoiceNoteRecordingView(
                        elapsedTime: pipeline.audioRecorder.elapsedTime,
                        onStop: {
                            Task { await pipeline.stopRecording() }
                        }
                    )

                case .transcribing:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(pipeline.transcriptionStatus)
                            .foregroundStyle(.secondary)
                        Text("This may take a moment on first use")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()

                case .editingTranscript:
                    TranscriptEditorView(
                        text: $editableTranscript,
                        onConfirm: { text in
                            Task {
                                await pipeline.confirmTranscript(
                                    editedText: text,
                                    passage: passage,
                                    axes: axes
                                )
                            }
                        },
                        onReRecord: {
                            pipeline.cancel()
                        }
                    )

                case .generatingVariants:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating comment variants...")
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                case .complete:
                    VariantListView(
                        variants: pipeline.variants,
                        selectedVariantID: $selectedVariantID,
                        onUseAsComment: { variant in
                            onUseAsComment(variant)
                            pipeline.reset()
                        },
                        onEditAndUse: { _ in },
                        onRegenerate: {
                            Task {
                                await pipeline.confirmTranscript(
                                    editedText: pipeline.transcriptText,
                                    passage: passage,
                                    axes: axes
                                )
                            }
                        }
                    )
                }
            }
        }
        .onChange(of: pipeline.transcriptText) { _, newValue in
            editableTranscript = newValue
        }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Record a voice note")
                .font(.headline)

            if passage.isEmpty {
                Text("Tip: select text in the PDF first for better context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                do {
                    try pipeline.startRecording(
                        annotationUUID: UUID(),
                        passage: passage
                    )
                } catch {
                    // Permission denied or recording failed
                }
            } label: {
                Label("Start Recording", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding()
    }
}
