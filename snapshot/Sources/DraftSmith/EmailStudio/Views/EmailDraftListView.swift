import SwiftUI

struct EmailDraftListView: View {
    let drafts: [EmailDraftVariant]
    let subjectOptions: [String]
    let onCopy: (String?, String) -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Email Drafts")
                    .font(.headline)
                Spacer()
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate All", systemImage: "arrow.clockwise")
                }
                .font(.caption)
            }

            if drafts.isEmpty {
                ContentUnavailableView {
                    Label("No Drafts", systemImage: "envelope")
                } description: {
                    Text("Enter your goal and generate email drafts.")
                }
            } else {
                ForEach(drafts) { draft in
                    EmailDraftCardView(
                        draft: draft,
                        subjectOptions: subjectOptions,
                        onCopy: onCopy,
                        onShorten: { onRegenerate() },
                        onSoften: { onRegenerate() },
                        onDirect: { onRegenerate() }
                    )
                }
            }
        }
    }
}
