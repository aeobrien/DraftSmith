import SwiftUI

struct EmailDraftCardView: View {
    let draft: EmailDraftVariant
    let subjectOptions: [String]
    @State private var selectedSubject: String?
    let onCopy: (String?, String) -> Void
    let onShorten: () -> Void
    let onSoften: () -> Void
    let onDirect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(draft.label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                AxesTagsView(axes: draft.axes)
            }

            // Subject picker
            if !subjectOptions.isEmpty {
                Picker("Subject", selection: $selectedSubject) {
                    ForEach(subjectOptions, id: \.self) { subject in
                        Text(subject).tag(subject as String?)
                    }
                }
                .onAppear {
                    selectedSubject = subjectOptions.first
                }
            }

            // Body
            Text(draft.body)
                .font(.body)
                .textSelection(.enabled)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Actions
            HStack(spacing: 8) {
                Button("Copy") {
                    onCopy(selectedSubject, draft.body)
                }
                .buttonStyle(.borderedProminent)

                Button("Shorten") { onShorten() }
                    .font(.caption)
                Button("Soften") { onSoften() }
                    .font(.caption)
                Button("More Direct") { onDirect() }
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AxesTagsView: View {
    let axes: VariantAxes

    var body: some View {
        HStack(spacing: 4) {
            if axes.directness > 0.6 {
                AxisTag(text: "Direct")
            } else if axes.directness < 0.4 {
                AxisTag(text: "Gentle")
            }
            if axes.brevity > 0.6 {
                AxisTag(text: "Thorough")
            } else if axes.brevity < 0.4 {
                AxisTag(text: "Brief")
            }
            if axes.formality > 0.6 {
                AxisTag(text: "Warm")
            } else if axes.formality < 0.4 {
                AxisTag(text: "Formal")
            }
        }
    }
}

private struct AxisTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
