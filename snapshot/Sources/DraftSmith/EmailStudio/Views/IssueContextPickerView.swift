import SwiftUI

struct IssueContextPickerView: View {
    let issues: [Issue]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insert Issue Context")
                .font(.headline)

            if issues.isEmpty {
                Text("No issues available. Run a grammar check first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(issues, id: \.id) { issue in
                    Button {
                        let context = formatIssueContext(issue)
                        onSelect(context)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: issue.issueSeverity.iconName)
                                    .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)
                                    .font(.caption)
                                Text("Page \(issue.pageIndex + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(issue.message)
                                .font(.body)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func formatIssueContext(_ issue: Issue) -> String {
        var lines: [String] = []
        lines.append("Issue: \(issue.message)")
        if !issue.selectionText.isEmpty {
            lines.append("Flagged text: \"\(issue.selectionText)\"")
        }
        if let category = issue.category {
            lines.append("Category: \(category)")
        }
        lines.append("Page: \(issue.pageIndex + 1)")
        return lines.joined(separator: "\n")
    }
}
