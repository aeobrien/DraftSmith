import SwiftUI
import AppKit

struct ProblemLogView: View {
    @Environment(ServiceManager.self) private var serviceManager
    @State private var messages: [ProblemLogMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isRecording = false
    @State private var recorder = AudioRecorder()
    @State private var errorMessage: String?
    @State private var reportGenerated = false
    @State private var reportText = ""

    private let chatClient = OpenAIChatClient()

    private let systemPrompt = """
    You are a support assistant for DraftSmith, a PDF proofreading application.
    Your role is to help the user clearly describe problems they're experiencing.

    CONVERSATION FLOW (follow this exactly):
    1. The user describes their problem. Listen carefully.
    2. Ask ONE set of clarifying questions (no more than 3 questions) to fill in gaps. \
    Do this in a single message. Do not ask further rounds of questions after this.
    3. Once you receive the user's answers, write a detailed description of the problem \
    in your own words and ask: "Does this accurately describe the problem? If anything \
    needs correcting, let me know. Otherwise, confirm and I'll generate the report."
    4. If the user says it's correct (e.g. "yes", "that's right", "confirmed", "looks good"), \
    IMMEDIATELY generate the structured report in the same message. Do NOT ask any more questions.
    5. If the user provides corrections, incorporate them, restate, and ask for confirmation again.

    REPORT FORMAT (when generating):
    **Summary:** (one sentence)

    **Steps to Reproduce:**
    1. ...
    2. ...

    **Expected Behaviour:**
    ...

    **Actual Behaviour:**
    ...

    **Additional Context:**
    ...

    RULES:
    - Be conversational, warm, and patient
    - Never discuss code, implementation, or technical details
    - Use the exact feature names and terminology from the App Guide
    - Keep the conversation focused — do not drag it out
    - Use markdown formatting in your responses

    [APP GUIDE]
    \(AppGuide.text)
    [/APP GUIDE]
    """

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Report a Problem")
                    .font(.headline)
                Spacer()
                if reportGenerated {
                    Button("Export Report") {
                        exportReport()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages.filter { $0.role != .system }) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        errorMessage = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Describe your problem...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isLoading || reportGenerated)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || reportGenerated)

                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.title2)
                        .foregroundStyle(isRecording ? .red : .primary)
                }
                .buttonStyle(.borderless)
                .disabled(isLoading || reportGenerated)
            }
            .padding()
        }
        .frame(minWidth: 550, minHeight: 450)
        .onAppear {
            if messages.isEmpty {
                messages.append(ProblemLogMessage(role: .system, content: systemPrompt))
                let greeting = ProblemLogMessage(
                    role: .assistant,
                    content: "Hi! I'm here to help you report a problem with DraftSmith. Please describe what's going on and I'll help you put together a clear report."
                )
                messages.append(greeting)
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        let userMessage = ProblemLogMessage(role: .user, content: text)
        messages.append(userMessage)
        sendToAPI()
    }

    private func sendToAPI() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await chatClient.sendMessages(messages)
                let assistantMessage = ProblemLogMessage(role: .assistant, content: response)
                messages.append(assistantMessage)

                // Check if this looks like a report
                if response.contains("Steps to Reproduce") || response.contains("Steps to reproduce") {
                    reportGenerated = true
                    reportText = response
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func toggleRecording() {
        if isRecording {
            isRecording = false
            guard let recording = recorder.stopRecording() else { return }
            isLoading = true
            Task {
                let result = try? await serviceManager.transcriptionService.transcribe(audioURL: recording.url)
                if let text = result?.text, !text.isEmpty {
                    inputText = text
                    sendMessage()
                } else {
                    errorMessage = "Could not transcribe recording."
                    isLoading = false
                }
            }
        } else {
            do {
                try recorder.startRecording(annotationUUID: UUID())
                isRecording = true
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "DraftSmith-Problem-Report.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var markdown = """
        # DraftSmith Problem Report
        **Date:** \(dateFormatter.string(from: Date()))

        \(reportText)

        ---

        ## Conversation Log

        """

        for message in messages where message.role != .system {
            let role = message.role == .user ? "User" : "Assistant"
            markdown += "**\(role):** \(message.content)\n\n"
        }

        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct MessageBubble: View {
    let message: ProblemLogMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Group {
                if message.role == .assistant {
                    Text(LocalizedStringKey(message.content))
                } else {
                    Text(message.content)
                }
            }
            .font(.body)
            .padding(10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .textSelection(.enabled)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .accentColor.opacity(0.15)
        case .assistant: return Color(.controlBackgroundColor)
        case .system: return .clear
        }
    }
}
