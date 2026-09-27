import SwiftUI

struct IssueQueueView: View {
    let issues: [Issue]
    let selectedIssue: Issue?
    let onSelectIssue: (Issue) -> Void
    let onResolveIssue: (Issue) -> Void
    let onDismissIssue: (Issue) -> Void

    @State private var filterStatus: IssueStatus? = .new
    @State private var showCategoryPopover = false
    @State private var disabledCategories: Set<String> = []

    var availableCategories: [String] {
        Set(issues.compactMap(\.category)).sorted()
    }

    var filteredIssues: [Issue] {
        var result = issues
        if let filter = filterStatus {
            result = result.filter { $0.issueStatus == filter }
        }
        result = result.filter { issue in
            guard let category = issue.category else { return true }
            return !disabledCategories.contains(category)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Issues")
                    .font(.headline)
                Spacer()

                Button {
                    showCategoryPopover = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        if !disabledCategories.isEmpty {
                            Text("\(disabledCategories.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.borderless)
                .help("Filter by category")
                .popover(isPresented: $showCategoryPopover) {
                    categoryPopoverContent
                }

                Text("\(filteredIssues.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Filter picker
            Picker("Filter", selection: $filterStatus) {
                Text("All").tag(nil as IssueStatus?)
                ForEach(IssueStatus.allCases, id: \.self) { status in
                    Label(status.displayName, systemImage: status.iconName)
                        .tag(status as IssueStatus?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            if filteredIssues.isEmpty {
                ContentUnavailableView {
                    Label("No Issues", systemImage: "checkmark.circle")
                } description: {
                    Text("No issues to display.")
                }
            } else {
                List(filteredIssues, id: \.id) { issue in
                    IssueRowView(issue: issue, isSelected: issue.id == selectedIssue?.id)
                        .onTapGesture {
                            onSelectIssue(issue)
                        }
                        .contextMenu {
                            Button("Resolve") { onResolveIssue(issue) }
                            Button("Dismiss") { onDismissIssue(issue) }
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: availableCategories) { _, newCategories in
            let validSet = Set(newCategories)
            disabledCategories = disabledCategories.intersection(validSet)
        }
    }

    private var categoryPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Categories")
                    .font(.headline)
                Spacer()
                Button("Show All") {
                    disabledCategories.removeAll()
                }
                .font(.caption)
                .disabled(disabledCategories.isEmpty)
            }
            .padding(.bottom, 4)

            if availableCategories.isEmpty {
                Text("No categories found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableCategories, id: \.self) { category in
                    Toggle(isOn: Binding(
                        get: { !disabledCategories.contains(category) },
                        set: { enabled in
                            if enabled {
                                disabledCategories.remove(category)
                            } else {
                                disabledCategories.insert(category)
                            }
                        }
                    )) {
                        Text(category)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
}

private struct IssueRowView: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: issue.issueSeverity.iconName)
                .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Page \(issue.pageIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let category = issue.category {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(issue.message)
                    .font(.body)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: issue.issueStatus.iconName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
    }
}
