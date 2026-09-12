import SwiftUI

struct CommentEditorView: View {
    @Binding var commentText: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Comment")
                    .font(.headline)
                Spacer()
                VoiceDictateButton { text in
                    if commentText.isEmpty {
                        commentText = text
                    } else {
                        commentText += " " + text
                    }
                }
            }

            TextEditor(text: $commentText)
                .font(.body)
                .frame(minHeight: 80)
                .focused($isFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave(commentText)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .onAppear {
            isFocused = true
        }
    }
}
