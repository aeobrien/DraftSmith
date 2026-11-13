import SwiftUI
import UniformTypeIdentifiers

struct EmailStudioView: View {
    @Environment(EmailStudioService.self) private var emailService
    @Environment(IssueManager.self) private var issueManager
    @Environment(StyleMemoryManager.self) private var styleMemoryManager

    @State private var recipientContext = ""
    @State private var goal = ""
    @State private var keyFacts = ""
    @State private var axes = PreferenceAxes.default
    @State private var showIssueContextPicker = false
    @State private var showStyleImporter = false
    @State private var importedEmailCount: Int = 0
    @State private var showImportConfirmation = false

    private let clipboardService = ClipboardService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Email Studio")
                    .font(.title)

                // Style reference section
                styleReferenceSection

                Divider()

                // Recipient Context
                GroupBox("Recipient Context (optional)") {
                    TextField("e.g. Senior editor at Oxford University Press", text: $recipientContext)
                }

                // Goal
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Goal")
                                .font(.subheadline)
                            Spacer()
                            VoiceDictateButton { text in
                                if goal.isEmpty {
                                    goal = text
                                } else {
                                    goal += " " + text
                                }
                            }
                        }
                        TextField("What needs to happen?", text: $goal)
                    }
                }

                // Key Facts
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Key Facts")
                                .font(.subheadline)
                            Spacer()
                            VoiceDictateButton { text in
                                if keyFacts.isEmpty {
                                    keyFacts = text
                                } else {
                                    keyFacts += "\n" + text
                                }
                            }
                            Button {
                                showIssueContextPicker = true
                            } label: {
                                Label("Insert Issue Context", systemImage: "doc.text.magnifyingglass")
                            }
                            .font(.caption)
                            .popover(isPresented: $showIssueContextPicker) {
                                IssueContextPickerView(
                                    issues: issueManager.fetchIssues(),
                                    onSelect: { context in
                                        if !keyFacts.isEmpty {
                                            keyFacts += "\n\n"
                                        }
                                        keyFacts += context
                                        showIssueContextPicker = false
                                    }
                                )
                            }
                        }

                        TextEditor(text: $keyFacts)
                            .font(.body)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                // Preference Axes
                PreferenceAxesView(axes: $axes) {}

                // Generate button
                Button {
                    Task {
                        let request = EmailGenerationRequest(
                            recipientContext: recipientContext,
                            goal: goal,
                            keyFacts: keyFacts,
                            axes: axes
                        )
                        try? await emailService.generateDrafts(request: request)
                    }
                } label: {
                    if emailService.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Generate Email Drafts", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(goal.isEmpty || emailService.isGenerating)

                // Results
                EmailDraftListView(
                    drafts: emailService.drafts,
                    subjectOptions: emailService.subjectOptions,
                    onCopy: { subject, body in
                        clipboardService.copyToClipboard(subject: subject, body: body)
                    },
                    onRegenerate: {
                        Task {
                            let request = EmailGenerationRequest(
                                recipientContext: recipientContext,
                                goal: goal,
                                keyFacts: keyFacts,
                                axes: axes
                            )
                            try? await emailService.generateDrafts(request: request)
                        }
                    }
                )
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showStyleImporter,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                importEmails(from: urls)
            }
        }
        .alert("Imported \(importedEmailCount) Style Emails", isPresented: $showImportConfirmation) {
            Button("OK") {}
        } message: {
            Text("These emails will be used as style references when generating drafts.")
        }
    }

    // MARK: - Style Reference Section

    private var styleReferenceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.secondary)
                    Text("Writing Style Reference")
                        .font(.subheadline.bold())
                    Spacer()
                    let count = existingEmailExampleCount
                    if count > 0 {
                        Text("\(count) example\(count == 1 ? "" : "s") loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Import examples of emails you've written so the LLM can match your tone and style. Separate emails with a line of three dashes (---).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        showStyleImporter = true
                    } label: {
                        Label("Import from File", systemImage: "doc.badge.plus")
                    }

                    if existingEmailExampleCount > 0 {
                        Button(role: .destructive) {
                            clearEmailExamples()
                        } label: {
                            Label("Clear Examples", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Import Logic

    private var existingEmailExampleCount: Int {
        styleMemoryManager.selectExamples(for: .emailDraft, budget: .max).count
    }

    private func importEmails(from urls: [URL]) {
        var totalImported = 0

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }

            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }

            // Split on "---" separator lines
            let emails = contents
                .components(separatedBy: "\n---\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // If no separators found, treat the whole file as one email
            let emailList = emails.isEmpty ? [contents.trimmingCharacters(in: .whitespacesAndNewlines)] : emails

            for email in emailList where !email.isEmpty {
                styleMemoryManager.addExamplePair(
                    input: "(Style reference — use this email's tone and phrasing as a guide)",
                    output: email,
                    category: .emailDraft
                )
                totalImported += 1
            }
        }

        importedEmailCount = totalImported
        if totalImported > 0 {
            showImportConfirmation = true
        }
    }

    private func clearEmailExamples() {
        let examples = styleMemoryManager.selectExamples(for: .emailDraft, budget: .max)
        for example in examples {
            styleMemoryManager.deleteExamplePair(example)
        }
    }
}
