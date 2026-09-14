import SwiftUI

struct VariantListView: View {
    let variants: [CommentVariant]
    @Binding var selectedVariantID: String?
    let onUseAsComment: (CommentVariant) -> Void
    let onEditAndUse: (CommentVariant) -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Variants")
                    .font(.headline)
                Spacer()
                Text("\(variants.count) options")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut(KeyboardShortcuts.regenerateVariants)
                .font(.caption)
            }

            if variants.isEmpty {
                ContentUnavailableView {
                    Label("No Variants", systemImage: "sparkles")
                } description: {
                    Text("Generating suggestions...")
                }
            } else {
                ForEach(variants) { variant in
                    VariantCardView(
                        variant: variant,
                        isSelected: variant.id == selectedVariantID,
                        onUseAsComment: { onUseAsComment(variant) },
                        onEditAndUse: { onEditAndUse(variant) },
                        onCopy: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(variant.text, forType: .string)
                        }
                    )
                    .onTapGesture {
                        selectedVariantID = variant.id
                    }
                }
            }
        }
    }
}
