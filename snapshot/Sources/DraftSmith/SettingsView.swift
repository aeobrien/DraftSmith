import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ProjectProfileEditorView()
                .tabItem {
                    Label("Project Profiles", systemImage: "folder")
                }

            StyleMemorySettingsView()
                .tabItem {
                    Label("Style Memory", systemImage: "brain")
                }

            PromptInspectorView()
                .tabItem {
                    Label("Prompt Inspector", systemImage: "text.magnifyingglass")
                }

            ServiceStatusSettingsView()
                .tabItem {
                    Label("Services", systemImage: "gear")
                }
        }
        .frame(width: 700, height: 500)
    }
}

private struct ServiceStatusSettingsView: View {
    @Environment(ServiceManager.self) private var serviceManager
    @Environment(ModelDownloadManager.self) private var downloadManager
    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved = false
    @State private var hasExistingKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Service Status")
                    .font(.title2)

                ForEach(ServiceKind.allCases) { kind in
                    HStack {
                        Circle()
                            .fill(stateColor(serviceManager.serviceState(for: kind)))
                            .frame(width: 12, height: 12)

                        Text(kind.displayName)
                            .font(.body)

                        Spacer()

                        Text(serviceManager.serviceState(for: kind).displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    Text("Used for the Problem Log chat feature. Stored securely in your macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        SecureField(hasExistingKey ? "Key saved — enter new key to replace" : "sk-proj-...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 400)

                        Button(apiKeySaved ? "Saved" : "Save") {
                            let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            _ = KeychainHelper.save(key: AppConstants.openAIAPIKeyKeychainKey, value: trimmed)
                            apiKeyInput = ""
                            apiKeySaved = true
                            hasExistingKey = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                apiKeySaved = false
                            }
                        }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if hasExistingKey {
                            Button("Remove") {
                                KeychainHelper.delete(key: AppConstants.openAIAPIKeyKeychainKey)
                                hasExistingKey = false
                                apiKeyInput = ""
                            }
                            .foregroundStyle(.red)
                        }
                    }

                    if hasExistingKey && !apiKeySaved {
                        Label("API key is stored in Keychain", systemImage: "checkmark.shield")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("System Information")
                        .font(.headline)
                    Text("RAM: \(String(format: "%.0f", SystemCapabilities.current.memoryGB)) GB")
                        .font(.caption)
                    Text("Recommended config: \(SystemCapabilities.current.recommendedModelConfig().displayDescription)")
                        .font(.caption)
                    if SystemCapabilities.current.isLowRAM {
                        Text("Low-RAM mode active: Whisper and LLM will not run simultaneously.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            hasExistingKey = KeychainHelper.read(key: AppConstants.openAIAPIKeyKeychainKey) != nil
        }
    }

    private func stateColor(_ state: ServiceState) -> Color {
        switch state {
        case .idle: return .gray
        case .loading: return .yellow
        case .ready: return .green
        case .error: return .red
        case .unloading: return .yellow
        }
    }
}
