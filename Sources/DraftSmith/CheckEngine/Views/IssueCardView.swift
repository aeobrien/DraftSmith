import SwiftUI

struct IssueCardView: View {
    let issue: Issue
    let onAddAsComment: (String) -> Void
    let onDismiss: () -> Void
    let onEditAndAdd: (String) -> Void

    private let diffEngine = WordDiffEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: issue.issueSeverity.iconName)
                    .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)

                VStack(alignment: .leading) {
                    Text(issue.message)
                        .font(.subheadline.bold())

                    HStack(spacing: 8) {
                        if let ruleID = issue.ruleID {
                            Text(ruleID)
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                        if let category = issue.category {
                            Text(category)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Spacer()
            }

            // Flagged text
            Text("\"\(issue.selectionText)\"")
                .font(.body)
                .italic()
                .padding(6)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Suggestions with visual diff
            if !issue.suggestionsList.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(issue.suggestionsList, id: \.self) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            let segments = diffEngine.diff(
                                original: issue.selectionText,
                                replacement: suggestion
                            )
                            VisualDiffView(segments: segments)

                            HStack(spacing: 8) {
                                Button("Add as Comment") {
                                    onAddAsComment(suggestion)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)

                                Button("Edit & Add") {
                                    onEditAndAdd(suggestion)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(8)
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Actions
            HStack {
                Spacer()
                Button("Dismiss", role: .destructive) {
                    onDismiss()
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
