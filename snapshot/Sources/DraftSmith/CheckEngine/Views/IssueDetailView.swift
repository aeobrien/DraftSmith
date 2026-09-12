import SwiftUI

struct IssueDetailView: View {
    let issue: Issue
    let onAddAsComment: (Issue, String) -> Void
    let onAddNaturalComment: (Issue, String) -> Void
    let onGenerateNaturalComment: (Issue, String) async -> String?
    let onEditComment: (Issue, String) -> Void
    let onDismiss: (Issue) -> Void
    let onResolve: (Issue) -> Void

    @State private var generatingForSuggestion: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: issue.issueSeverity.iconName)
                        .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)
                    Text(issue.message)
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: issue.issueStatus)
                }

                // Copilot-rewritten comment
                if let rewritten = issue.rewrittenComment, !rewritten.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text("Rewritten")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(rewritten)
                            .font(.body)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(rewritten, forType: .string)
                        } label: {
                            Label("Copy Rewrite", systemImage: "doc.on.doc")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }

                Divider()

                // Flagged text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flagged Text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(issue.selectionText)
                        .font(.body)
                        .padding(8)
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Issue type
                if let category = issue.category {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Issue Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Comment actions (always visible when no suggestions)
                if issue.suggestionsList.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            let category = issue.category ?? "Issue"
                            onAddAsComment(issue, "\(category): \(issue.message)")
                        } label: {
                            Label("Quick", systemImage: "bolt")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button {
                            onAddNaturalComment(issue, issue.message)
                        } label: {
                            Label("Natural", systemImage: "sparkles")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button {
                            onEditComment(issue, issue.message)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }

                // Suggestions
                if !issue.suggestionsList.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(issue.suggestionsList, id: \.self) { suggestion in
                            SuggestionOptionRow(
                                suggestion: suggestion,
                                category: issue.category,
                                isGenerating: generatingForSuggestion == suggestion,
                                onQuick: {
                                    let category = issue.category ?? "Issue"
                                    onAddAsComment(issue, "\(category): \(suggestion)")
                                },
                                onNatural: {
                                    onAddNaturalComment(issue, suggestion)
                                },
                                onEdit: {
                                    generatingForSuggestion = suggestion
                                    Task {
                                        if let comment = await onGenerateNaturalComment(issue, suggestion) {
                                            onEditComment(issue, comment)
                                        }
                                        generatingForSuggestion = nil
                                    }
                                }
                            )
                        }
                    }
                }

                Divider()

                // Actions
                HStack {
                    Button("Dismiss") {
                        onDismiss(issue)
                    }
                    Spacer()
                    Button("Mark Resolved") {
                        onResolve(issue)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

private struct SuggestionOptionRow: View {
    let suggestion: String
    let category: String?
    let isGenerating: Bool
    let onQuick: () -> Void
    let onNatural: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion)
                .font(.body)

            HStack(spacing: 8) {
                Button {
                    onQuick()
                } label: {
                    Label("Quick", systemImage: "bolt")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .help("Add structured comment: \"\(category ?? "Issue"): \(suggestion)\"")

                Button {
                    onNatural()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Label("Natural", systemImage: "sparkles")
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(isGenerating)
                .help("Generate a natural-language comment using AI")

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(isGenerating)
                .help("Generate a comment and edit before adding")
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct StatusBadge: View {
    let status: IssueStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
            Text(status.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var backgroundColor: Color {
        switch status {
        case .new: return .orange.opacity(0.15)
        case .resolved: return .green.opacity(0.15)
        case .dismissed: return .gray.opacity(0.15)
        }
    }
}
