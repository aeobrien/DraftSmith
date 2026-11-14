import SwiftUI

struct RewritePanelView: View {
    let passage: String
    @Binding var variants: [CommentVariant]
    @Binding var axes: PreferenceAxes
    let isGenerating: Bool
    let onUseAsComment: (CommentVariant) -> Void
    let onEditAndUse: (CommentVariant) -> Void
    let onRegenerate: () -> Void

    @State private var selectedVariantID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Original passage
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Passage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(passage)
                        .font(.body)
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Divider()

                // Preference axes
                PreferenceAxesView(axes: $axes) {
                    onRegenerate()
                }

                Divider()

                // Variants
                if isGenerating {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating variants...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                VariantListView(
                    variants: variants,
                    selectedVariantID: $selectedVariantID,
                    onUseAsComment: onUseAsComment,
                    onEditAndUse: onEditAndUse,
                    onRegenerate: onRegenerate
                )
            }
            .padding()
        }
    }
}
