import SwiftUI

struct VerifyTextView: View {
    @Binding var text: String
    let confidence: ExtractionConfidence
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Low-confidence text extraction")
                    .font(.headline)
            }

            Text("The extracted text may contain errors. Please verify and correct before checking.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Check Corrected Text") {
                    onConfirm(text)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
