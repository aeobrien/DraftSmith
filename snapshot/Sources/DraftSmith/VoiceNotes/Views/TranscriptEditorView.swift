import SwiftUI

struct TranscriptEditorView: View {
    @Binding var text: String
    let onConfirm: (String) -> Void
    let onReRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)

            Text("Review and edit the transcript before generating comment variants.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Re-record") {
                    onReRecord()
                }

                Spacer()

                Button("Confirm & Generate") {
                    onConfirm(text)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}
