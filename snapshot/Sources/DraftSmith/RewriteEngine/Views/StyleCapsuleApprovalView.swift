import SwiftUI

struct StyleCapsuleApprovalView: View {
    let currentCapsule: String
    let proposedCapsule: StyleCapsule
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("New Style Capsule Suggested")
                    .font(.headline)
            }

            Text("Draftsmith has noticed patterns in your editing. Review the proposed Style Capsule below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            GroupBox("Current") {
                if currentCapsule.isEmpty {
                    Text("(No active capsule)")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(currentCapsule)
                        .font(.body)
                }
            }

            GroupBox("Proposed") {
                Text(proposedCapsule.capsuleText)
                    .font(.body)

                if !proposedCapsule.keyTendencies.isEmpty {
                    HStack {
                        ForEach(proposedCapsule.keyTendencies, id: \.self) { tendency in
                            Text(tendency)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            HStack {
                Button("Dismiss") {
                    onDismiss()
                }
                Spacer()
                Button("Apply") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
