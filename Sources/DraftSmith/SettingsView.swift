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
