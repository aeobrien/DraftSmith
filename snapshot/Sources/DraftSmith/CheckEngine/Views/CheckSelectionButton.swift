import SwiftUI

struct CheckSelectionButton: View {
    let hasSelection: Bool
    let isChecking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isChecking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Check Selection", systemImage: "textformat.abc.dottedunderline")
            }
        }
        .keyboardShortcut(KeyboardShortcuts.checkSelection)
        .disabled(!hasSelection || isChecking)
        .help("Check selected text for grammar and style issues (Cmd+Shift+C)")
    }
}
