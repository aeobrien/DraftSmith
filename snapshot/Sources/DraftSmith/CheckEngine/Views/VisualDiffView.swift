import SwiftUI

struct VisualDiffView: View {
    let segments: [DiffSegment]

    var body: some View {
        FlowLayout(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .font(.body)
                    .foregroundStyle(foregroundColor(for: segment))
                    .strikethrough(segment.isDeleted, color: .red)
                    .underline(segment.isInserted, color: .green)
                    .background(backgroundColor(for: segment))
            }
        }
    }

    private func foregroundColor(for segment: DiffSegment) -> Color {
        switch segment {
        case .unchanged: return .primary
        case .deleted: return .red
        case .inserted: return .green
        }
    }

    private func backgroundColor(for segment: DiffSegment) -> Color {
        switch segment {
        case .unchanged: return .clear
        case .deleted: return .red.opacity(0.1)
        case .inserted: return .green.opacity(0.1)
        }
    }
}

/// A simple flow layout that wraps content horizontally.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
            totalHeight = max(totalHeight, y + maxHeight)
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
