import SwiftUI

struct VoiceNoteRecordingView: View {
    let elapsedTime: TimeInterval
    let onStop: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            // Pulsing red dot
            Circle()
                .fill(.red)
                .frame(width: 16, height: 16)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }

            Text("Recording...")
                .font(.headline)

            Text(formatTime(elapsedTime))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("Stop") {
                onStop()
            }
            .keyboardShortcut(.space, modifiers: .control)
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int(time * 10) % 10
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
