import SwiftUI

struct IssueBottomBarView: View {
    let issues: [Issue]
    @Binding var selectedIssue: Issue?
    let onSelectIssue: (Issue) -> Void
    let onResolveIssue: (Issue) -> Void
    let onDismissIssue: (Issue) -> Void
    let onAddAsComment: (Issue, String) -> Void
    let onAddNaturalComment: (Issue, String) -> Void
    let onGenerateNaturalComment: (Issue, String) async -> String?
    let onEditComment: (Issue, String) -> Void
    let onDismissAllMatchingText: (Issue) -> Void
    let onDismissAllMatchingRule: (Issue) -> Void
    let onAddToDictionary: (Issue) -> Void

    @State private var filterStatus: IssueStatus? = .new
    @State private var showCategoryPopover = false
    @State private var showRuleInfoPopover = false
    @State private var disabledCategories: Set<String> = []
    @FocusState private var isFocused: Bool

    private var availableCategories: [String] {
        Set(issues.compactMap(\.category)).sorted()
    }

    private var filteredIssues: [Issue] {
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

    private var currentIndex: Int? {
        guard let selected = selectedIssue else { return nil }
        return filteredIssues.firstIndex(where: { $0.id == selected.id })
    }

    var body: some View {
        HStack(spacing: 0) {
            issueStrip
                .frame(minWidth: 220, maxWidth: 220, maxHeight: .infinity)

            Divider()

            issueDetailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 260)
        .background(Color(.windowBackgroundColor))
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) {
            navigateToNextIssue()
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigateToPreviousIssue()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "d")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            onDismissIssue(issue)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "a")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            onAddToDictionary(issue)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "r")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            onDismissAllMatchingRule(issue)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: ".")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            onDismissAllMatchingText(issue)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "q")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            let suggestion = issue.suggestionsList.first ?? issue.message
            let category = issue.category ?? "Issue"
            onAddAsComment(issue, "\(category): \(suggestion)")
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "n")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            let suggestion = issue.suggestionsList.first ?? issue.message
            onAddNaturalComment(issue, suggestion)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "e")) { _ in
            guard let issue = selectedIssue else { return .ignored }
            let suggestion = issue.suggestionsList.first ?? ""
            onEditComment(issue, suggestion)
            return .handled
        }
        .onChange(of: availableCategories) { _, newCategories in
            let validSet = Set(newCategories)
            disabledCategories = disabledCategories.intersection(validSet)
        }
    }

    // MARK: - Issue Strip (left — narrow list)

    private var issueStrip: some View {
        VStack(spacing: 0) {
            // Controls row
            HStack(spacing: 6) {
                Menu {
                    Button("All") { filterStatus = nil }
                    Divider()
                    ForEach(IssueStatus.allCases, id: \.self) { status in
                        Button(status.displayName) { filterStatus = status }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterStatus?.iconName ?? "line.3.horizontal.decrease")
                        Text(filterStatus?.displayName ?? "All")
                            .font(.caption)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    showCategoryPopover = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                            .font(.caption2)
                        if !disabledCategories.isEmpty {
                            Text("\(disabledCategories.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showCategoryPopover) {
                    categoryPopoverContent
                }

                Spacer()

                Text("\(filteredIssues.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Issue list
            if filteredIssues.isEmpty {
                VStack {
                    Spacer()
                    Text("No issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredIssues, id: \.id) { issue in
                                BottomBarIssueRowView(
                                    issue: issue,
                                    isSelected: issue.id == selectedIssue?.id
                                )
                                .id(issue.id)
                                .onTapGesture {
                                    onSelectIssue(issue)
                                }
                                Divider()
                            }
                        }
                    }
                    .onChange(of: selectedIssue?.id) { _, newID in
                        if let newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Issue Detail Pane (right — card style)

    private var issueDetailPane: some View {
        Group {
            if let issue = selectedIssue {
                issueDetailContent(for: issue)
            } else {
                ContentUnavailableView("No Issue Selected", systemImage: "doc.text", description: Text("Select an issue from the list to view details."))
            }
        }
    }

    private func issueDetailContent(for issue: Issue) -> some View {
        VStack(spacing: 0) {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: severity + category + position indicator
                    HStack(spacing: 8) {
                        Image(systemName: issue.issueSeverity.iconName)
                            .font(.title3)
                            .foregroundStyle(issue.issueSeverity == .warning ? .orange : .blue)
                        if let category = issue.category {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                        if let idx = currentIndex {
                            Text("\(idx + 1) of \(filteredIssues.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // The main message — this is the focal point
                    Text(issue.message)
                        .font(.title3.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    // Copilot-rewritten comment (if available)
                    if let rewritten = issue.rewrittenComment, !rewritten.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                Text("Rewritten")
                                    .font(.caption)
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
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }

                    // Flagged text in a prominent box
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flagged text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(issue.selectionText)
                            .font(.body)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Comment actions (always visible)
                    if issue.suggestionsList.isEmpty {
                        HStack(spacing: 6) {
                            Button {
                                let category = issue.category ?? "Issue"
                                onAddAsComment(issue, "\(category): \(issue.message)")
                            } label: {
                                Label("Quick (Q)", systemImage: "bolt")
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button {
                                onAddNaturalComment(issue, issue.message)
                            } label: {
                                Label("Natural (N)", systemImage: "sparkles")
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button {
                                onEditComment(issue, issue.message)
                            } label: {
                                Label("Edit (E)", systemImage: "pencil")
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }

                    // Suggestions
                    if !issue.suggestionsList.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestions")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(issue.suggestionsList, id: \.self) { suggestion in
                                BottomBarSuggestionRow(
                                    issue: issue,
                                    suggestion: suggestion,
                                    onQuick: {
                                        let category = issue.category ?? "Issue"
                                        onAddAsComment(issue, "\(category): \(suggestion)")
                                    },
                                    onNatural: {
                                        onAddNaturalComment(issue, suggestion)
                                    },
                                    onEdit: onEditComment,
                                    onGenerateNaturalComment: onGenerateNaturalComment
                                )
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Fixed action bar at bottom
            HStack(spacing: 6) {
                Button("Dismiss (D)") {
                    onDismissIssue(issue)
                }
                .controlSize(.small)
                .keyboardShortcut(.none)

                Button("Resolve") {
                    onResolveIssue(issue)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.none)

                if let rewritten = issue.rewrittenComment, !rewritten.isEmpty {
                    Button {
                        onAddAsComment(issue, rewritten)
                    } label: {
                        Label("Use Rewrite", systemImage: "sparkles")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }

                Divider()
                    .frame(height: 16)

                Button {
                    onDismissAllMatchingText(issue)
                } label: {
                    Text("Dismiss All (.) \"\(issue.selectionText.prefix(12))\(issue.selectionText.count > 12 ? "\u{2026}" : "")\"")
                }
                .controlSize(.mini)
                .font(.caption2)

                if let ruleID = issue.ruleID {
                    Button("Dismiss Rule (R)") {
                        onDismissAllMatchingRule(issue)
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
                        ruleInfoPopoverContent(issue: issue, ruleID: ruleID)
                    }
                }

                Spacer()

                Button("Dictionary (A)") {
                    onAddToDictionary(issue)
                }
                .controlSize(.mini)
                .font(.caption2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor).opacity(0.5))
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor).opacity(0.4))
        )
        .padding(6)
    }

    // MARK: - Category Popover

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

    // MARK: - Navigation

    private func navigateToNextIssue() {
        guard !filteredIssues.isEmpty else { return }
        if let current = selectedIssue,
           let idx = filteredIssues.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = filteredIssues.index(after: idx)
            if nextIdx < filteredIssues.endIndex {
                onSelectIssue(filteredIssues[nextIdx])
            }
        } else {
            onSelectIssue(filteredIssues[0])
        }
    }

    private func navigateToPreviousIssue() {
        guard !filteredIssues.isEmpty else { return }
        if let current = selectedIssue,
           let idx = filteredIssues.firstIndex(where: { $0.id == current.id }) {
            if idx > filteredIssues.startIndex {
                let prevIdx = filteredIssues.index(before: idx)
                onSelectIssue(filteredIssues[prevIdx])
            }
        } else {
            onSelectIssue(filteredIssues[filteredIssues.count - 1])
        }
    }

    private func ruleInfoPopoverContent(issue: Issue, ruleID: String) -> some View {
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
        .frame(minWidth: 220, maxWidth: 320)
    }
}

// MARK: - Private Subviews

private struct BottomBarIssueRowView: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(issue.issueSeverity == .warning ? .orange : .blue)
                .frame(width: 6, height: 6)

            Text(issue.message)
                .font(.caption)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        .contentShape(Rectangle())
    }
}

private struct BottomBarSuggestionRow: View {
    let issue: Issue
    let suggestion: String
    let onQuick: () -> Void
    let onNatural: () -> Void
    let onEdit: (Issue, String) -> Void
    let onGenerateNaturalComment: (Issue, String) async -> String?

    @State private var isGenerating = false

    private let diffEngine = WordDiffEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VisualDiffView(segments: diffEngine.diff(original: issue.selectionText, replacement: suggestion))

            HStack(spacing: 6) {
                Button {
                    onQuick()
                } label: {
                    Label("Quick (Q)", systemImage: "bolt")
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button {
                    onNatural()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Label("Natural (N)", systemImage: "sparkles")
                    }
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isGenerating)

                Button {
                    isGenerating = true
                    Task {
                        if let comment = await onGenerateNaturalComment(issue, suggestion) {
                            onEdit(issue, comment)
                        }
                        isGenerating = false
                    }
                } label: {
                    Label("Edit (E)", systemImage: "pencil")
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isGenerating)
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct BottomBarStatusBadge: View {
    let status: IssueStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.iconName)
            Text(status.displayName)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var backgroundColor: Color {
        switch status {
        case .new: return .orange.opacity(0.15)
        case .resolved: return .green.opacity(0.15)
        case .dismissed: return .gray.opacity(0.15)
        }
    }
}
