import SwiftUI

struct StyleMemorySettingsView: View {
    @Environment(StyleMemoryManager.self) private var styleMemoryManager

    @State private var examplePairs: [ExamplePair] = []
    @State private var feedbackEvents: [FeedbackEvent] = []
    @State private var newInputText = ""
    @State private var newOutputText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Current Capsule
                GroupBox("Active Style Capsule") {
                    VStack(alignment: .leading, spacing: 8) {
                        if styleMemoryManager.activeCapsuleText.isEmpty {
                            Text("No active style capsule.")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(styleMemoryManager.activeCapsuleText)
                                .font(.body)
                        }

                        HStack {
                            Spacer()
                            Button("Reset to Default", role: .destructive) {
                                styleMemoryManager.resetCapsule()
                            }
                            .font(.caption)
                        }
                    }
                }

                // Example Pairs
                GroupBox("Example Pairs (\(examplePairs.count))") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(examplePairs, id: \.id) { pair in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Input:")
                                        .font(.caption.bold())
                                    Text(pair.inputText)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                                HStack {
                                    Text("Output:")
                                        .font(.caption.bold())
                                    Text(pair.outputText)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                            }
                            .padding(6)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    styleMemoryManager.deleteExamplePair(pair)
                                    refreshData()
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add Example Pair")
                                .font(.caption.bold())
                            TextField("Input (rough thought)", text: $newInputText)
                            TextField("Output (final phrasing)", text: $newOutputText)
                            Button("Add") {
                                guard !newInputText.isEmpty, !newOutputText.isEmpty else { return }
                                styleMemoryManager.addExamplePair(
                                    input: newInputText,
                                    output: newOutputText,
                                    category: .diplomaticComment
                                )
                                newInputText = ""
                                newOutputText = ""
                                refreshData()
                            }
                            .disabled(newInputText.isEmpty || newOutputText.isEmpty)
                        }
                    }
                }

                // Feedback Log
                GroupBox("Feedback Log (\(feedbackEvents.count) events)") {
                    if feedbackEvents.isEmpty {
                        Text("No feedback events recorded yet.")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(feedbackEvents.prefix(10), id: \.id) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tags: \(event.editIntentTags.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Length change: \(String(format: "%.0f%%", event.lengthChangeRatio * 100))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(4)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            refreshData()
        }
    }

    private func refreshData() {
        examplePairs = styleMemoryManager.fetchAllExamplePairs()
        feedbackEvents = styleMemoryManager.fetchAllFeedbackEvents()
    }
}
