import SwiftUI

struct IssuePopoverView: View {
    let issue: Issue
    let onDismiss: () -> Void
    let onResolve: () -> Void
    let onAddAsComment: (String) -> Void
    let onAddNaturalComment: (String) -> Void
    let onEditComment: (String) -> Void
    let onDismissAllMatchingText: () -> Void
    let onDismissAllMatchingRule: () -> Void
    let onAddToDictionary: () -> Void

    @State private var showRuleInfoPopover = false

    private let diffEngine = WordDiffEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: severity icon + message
            HStack(spacing: 6) {
                Image(systemName: issue.issueSeverity.iconName)
                    .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)
                Text(issue.message)
                    .font(.callout.weight(.medium))
                    .lineLimit(3)
            }

            // Flagged text
            Text(issue.selectionText)
                .font(.callout)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Comment actions (always visible when no suggestions)
            if issue.suggestionsList.isEmpty {
                HStack(spacing: 4) {
                    Button {
                        let category = issue.category ?? "Issue"
                        onAddAsComment("\(category): \(issue.message)")
                    } label: {
                        Label("Quick (Q)", systemImage: "bolt")
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        onAddNaturalComment(issue.message)
                    } label: {
                        Label("Natural (N)", systemImage: "sparkles")
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        onEditComment(issue.message)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            // Suggestions
            if !issue.suggestionsList.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(issue.suggestionsList.prefix(3), id: \.self) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            VisualDiffView(segments: diffEngine.diff(
                                original: issue.selectionText,
                                replacement: suggestion
                            ))
                            .font(.caption)

                            HStack(spacing: 4) {
                                Button {
                                    let category = issue.category ?? "Issue"
                                    onAddAsComment("\(category): \(suggestion)")
                                } label: {
                                    Label("Quick (Q)", systemImage: "bolt")
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button {
                                    onAddNaturalComment(suggestion)
                                } label: {
                                    Label("Natural (N)", systemImage: "sparkles")
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button {
                                    onEditComment(suggestion)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        .padding(6)
                        .background(Color.green.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Divider()

            // Action bar
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Button("Dismiss (D)") {
                        onDismiss()
                    }
                    .controlSize(.small)

                    Button("Resolve (R)") {
                        onResolve()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Add to Dictionary") {
                        onAddToDictionary()
                    }
                    .controlSize(.mini)
                    .font(.caption2)
                }

                HStack(spacing: 6) {
                    Button {
                        onDismissAllMatchingText()
                    } label: {
                        Text("Dismiss All \"\(issue.selectionText.prefix(15))\(issue.selectionText.count > 15 ? "\u{2026}" : "")\"")
                    }
                    .controlSize(.mini)
                    .font(.caption2)

                    if let ruleID = issue.ruleID {
                        HStack(spacing: 2) {
                            Button("Dismiss All from Rule") {
                                onDismissAllMatchingRule()
                            }
                            .controlSize(.mini)
                            .font(.caption2)

                            Button {
                                showRuleInfoPopover = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .popover(isPresented: $showRuleInfoPopover) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Rule Explanation")
                                        .font(.caption.weight(.semibold))
                                    Text(issue.message)
                                        .font(.callout)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let category = issue.category {
                                        HStack(spacing: 4) {
                                            Text("Category:")
                                                .foregroundStyle(.secondary)
                                            Text(category)
                                        }
                                        .font(.caption)
                                    }
                                    Text(ruleID)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .textSelection(.enabled)
                                }
                                .padding()
                                .frame(minWidth: 220, maxWidth: 300)
                            }
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
