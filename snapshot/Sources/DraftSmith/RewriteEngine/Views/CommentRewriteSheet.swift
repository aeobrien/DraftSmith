import SwiftUI

struct CommentRewriteSheet: View {
    let annotation: DSAnnotation
    let direction: CommentRewriteDirection
    let onApply: (DSAnnotation, String) -> Void
    let onCancel: () -> Void

    @Environment(RewriteEngine.self) private var rewriteEngine

    @State private var variants: [CommentVariant] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var customPrompt = ""
    @State private var activeDirection: CommentRewriteDirection

    init(
        annotation: DSAnnotation,
        direction: CommentRewriteDirection,
        onApply: @escaping (DSAnnotation, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.annotation = annotation
        self.direction = direction
        self.onApply = onApply
        self.onCancel = onCancel
        _activeDirection = State(initialValue: direction)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rewrite Comment")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original comment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(annotation.commentText)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Direction buttons
                    HStack(spacing: 8) {
                        DirectionButton(label: "Softer", icon: "hand.wave", isActive: isSofter) {
                            activeDirection = .softer
                            Task { await generateVariants() }
                        }
                        DirectionButton(label: "More Direct", icon: "bolt", isActive: isDirect) {
                            activeDirection = .moreDirect
                            Task { await generateVariants() }
                        }
                    }

                    // Custom prompt
                    HStack {
                        TextField("Custom instruction...", text: $customPrompt)
                            .textFieldStyle(.roundedBorder)
                        Button("Go") {
                            guard !customPrompt.isEmpty else { return }
                            activeDirection = .custom(customPrompt)
                            Task { await generateVariants() }
                        }
                        .disabled(customPrompt.isEmpty)
                    }

                    Divider()

                    // Variants or loading
                    if isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Generating variants...")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if let error = errorMessage {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .foregroundStyle(.secondary)
                                Button("Retry") {
                                    Task { await generateVariants() }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        ForEach(variants) { variant in
                            RewriteVariantRow(variant: variant) {
                                onApply(annotation, variant.text)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await generateVariants()
        }
    }

    private var isSofter: Bool {
        if case .softer = activeDirection { return true }
        return false
    }

    private var isDirect: Bool {
        if case .moreDirect = activeDirection { return true }
        return false
    }

    private func generateVariants() async {
        isLoading = true
        errorMessage = nil
        do {
            variants = try await rewriteEngine.rewriteComment(
                commentText: annotation.commentText,
                direction: activeDirection
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct DirectionButton: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .tint(isActive ? .accentColor : nil)
    }
}

private struct RewriteVariantRow: View {
    let variant: CommentVariant
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(variant.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Text(variant.text)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
