import SwiftUI

struct VariantCardView: View {
    let variant: CommentVariant
    let isSelected: Bool
    let onUseAsComment: () -> Void
    let onEditAndUse: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(variant.label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                AxesIndicator(axes: variant.axes)
            }

            // Text
            Text(variant.text)
                .font(.body)
                .textSelection(.enabled)

            // Actions
            HStack(spacing: 8) {
                Button("Use as Comment") {
                    onUseAsComment()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)

                Button("Edit & Use") {
                    onEditAndUse()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .font(.caption)
                .help("Copy to clipboard")
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

private struct AxesIndicator: View {
    let axes: VariantAxes

    var body: some View {
        HStack(spacing: 4) {
            AxisDot(value: axes.directness, lowLabel: "G", highLabel: "D")
            AxisDot(value: axes.brevity, lowLabel: "B", highLabel: "T")
            AxisDot(value: axes.formality, lowLabel: "F", highLabel: "W")
        }
    }
}

private struct AxisDot: View {
    let value: Double
    let lowLabel: String
    let highLabel: String

    var body: some View {
        Text(value < 0.5 ? lowLabel : highLabel)
            .font(.system(size: 8).bold())
            .frame(width: 14, height: 14)
            .background(
                Circle()
                    .fill(Color.accentColor.opacity(0.2 + value * 0.5))
            )
            .foregroundStyle(.secondary)
    }
}
