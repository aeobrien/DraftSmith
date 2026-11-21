import SwiftUI

struct CommentSidebarView: View {
    let annotations: [DSAnnotation]
    let hasSelection: Bool
    let rewriteSuggestions: [UUID: String]
    let selectedAnnotationID: UUID?
    let onNavigateToAnnotation: (DSAnnotation) -> Void
    let onSelectAnnotation: (DSAnnotation) -> Void
    let onAddComment: () -> Void
    let onAddVoiceComment: (String) -> Void
    let onDeleteAnnotation: (DSAnnotation) -> Void
    let onRewriteAnnotation: (DSAnnotation, CommentRewriteDirection) -> Void
    let onRevertAnnotation: (DSAnnotation) -> Void
    let onEditAnnotation: (DSAnnotation) -> Void
    let onApplySuggestion: (DSAnnotation, String) -> Void
    let onDismissSuggestion: (DSAnnotation) -> Void
    let onRequestRewrite: ((DSAnnotation) -> Void)?

    @State private var searchText = ""
    @State private var generatingRewriteFor: UUID?

    var filteredAnnotations: [DSAnnotation] {
        if searchText.isEmpty {
            return annotations
        }
        return annotations.filter {
            $0.commentText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Text("\(annotations.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            TextField("Search comments...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if filteredAnnotations.isEmpty {
                ContentUnavailableView {
                    Label("No Comments", systemImage: "text.bubble")
                } description: {
                    if annotations.isEmpty {
                        Text("Select text and add a comment, or use the mic to dictate.")
                    } else {
                        Text("No comments match your search.")
                    }
                }
            } else {
                ScrollViewReader { proxy in
                List(filteredAnnotations) { annotation in
                    VStack(alignment: .leading, spacing: 0) {
                        CommentRowView(
                            annotation: annotation,
                            isRewritten: annotation.originalCommentText != nil
                        )
                        .onTapGesture {
                            onSelectAnnotation(annotation)
                            onNavigateToAnnotation(annotation)
                        }

                        if let suggestion = rewriteSuggestions[annotation.id] {
                            SuggestionRow(
                                suggestion: suggestion,
                                onApply: { onApplySuggestion(annotation, suggestion) },
                                onDismiss: { onDismissSuggestion(annotation) }
                            )
                        }

                        // Inline action buttons
                        HStack(spacing: 8) {
                            Button {
                                onEditAnnotation(annotation)
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Edit comment")

                            Button(role: .destructive) {
                                onDeleteAnnotation(annotation)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Delete comment")

                            if rewriteSuggestions[annotation.id] == nil {
                                if generatingRewriteFor == annotation.id {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .help("Generating rewrite\u{2026}")
                                } else {
                                    Button {
                                        generatingRewriteFor = annotation.id
                                        onRequestRewrite?(annotation)
                                    } label: {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.mini)
                                    .help("Suggest rewrite")
                                }
                            }

                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .id(annotation.id)
                    .listRowSeparator(.visible)
                    .listRowBackground(
                        annotation.id == selectedAnnotationID
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .contextMenu {
                        Button {
                            onEditAnnotation(annotation)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button {
                            onRewriteAnnotation(annotation, .softer)
                        } label: {
                            Label("Make Softer", systemImage: "hand.wave")
                        }

                        Button {
                            onRewriteAnnotation(annotation, .moreDirect)
                        } label: {
                            Label("Make More Direct", systemImage: "bolt")
                        }

                        Button {
                            onRewriteAnnotation(annotation, .custom(""))
                        } label: {
                            Label("Rewrite...", systemImage: "pencil.and.outline")
                        }

                        if annotation.originalCommentText != nil {
                            Divider()
                            Button {
                                onRevertAnnotation(annotation)
                            } label: {
                                Label("Revert to Original", systemImage: "arrow.uturn.backward")
                            }
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            onDeleteAnnotation(annotation)
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedAnnotationID) { _, newID in
                    if let newID {
                        withAnimation {
                            proxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
                .onChange(of: rewriteSuggestions.count) { _, _ in
                    // Clear loading state when a suggestion arrives
                    if let id = generatingRewriteFor, rewriteSuggestions[id] != nil {
                        generatingRewriteFor = nil
                    }
                }
                } // ScrollViewReader
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: onAddComment) {
                    Label("Add Comment", systemImage: "plus.bubble")
                }
                .disabled(!hasSelection)

                VoiceDictateButton { transcription in
                    onAddVoiceComment(transcription)
                }
                .help("Record a voice comment")
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Suggested rewrite")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(suggestion)
                .font(.callout)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            HStack(spacing: 8) {
                Button("Apply") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                Button("Dismiss") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

private struct CommentRowView: View {
    let annotation: DSAnnotation
    let isRewritten: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Page \(annotation.pageIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isRewritten {
                    Image(systemName: "pencil.line")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Rewritten (right-click to revert)")
                }
                Image(systemName: sourceIcon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(annotation.commentText)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: String {
        switch annotation.metadata.source {
        case .manual: return "hand.draw"
        case .languageTool: return "textformat.abc"
        case .llmRewrite: return "sparkles"
        case .voiceNote: return "mic"
        }
    }
}
