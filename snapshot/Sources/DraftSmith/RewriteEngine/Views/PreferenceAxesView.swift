import SwiftUI

struct PreferenceAxesView: View {
    @Binding var axes: PreferenceAxes
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preference Axes")
                .font(.subheadline.bold())

            AxisSlider(
                label: "Gentle",
                endLabel: "Direct",
                value: $axes.directness,
                onChanged: onChanged
            )

            AxisSlider(
                label: "Brief",
                endLabel: "Thorough",
                value: $axes.brevity,
                onChanged: onChanged
            )

            AxisSlider(
                label: "Formal",
                endLabel: "Warm",
                value: $axes.formality,
                onChanged: onChanged
            )

            AxisSlider(
                label: "Comment",
                endLabel: "Rewrite",
                value: $axes.rewriteVsComment,
                onChanged: onChanged
            )
        }
        .padding()
    }
}

private struct AxisSlider: View {
    let label: String
    let endLabel: String
    @Binding var value: Double
    let onChanged: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Slider(value: $value, in: 0...1, step: 0.1)
                    .onChange(of: value) { _, _ in
                        onChanged()
                    }

                Text(endLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}
