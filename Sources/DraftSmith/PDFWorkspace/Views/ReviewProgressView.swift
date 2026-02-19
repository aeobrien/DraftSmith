import SwiftUI

struct ReviewProgressView: View {
    @Environment(ReviewProgressTracker.self) private var progressTracker

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: progressTracker.progressPercentage)
                .frame(width: 100)

            Text(progressTracker.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}
