import SwiftUI

struct ServiceStatusBarView: View {
    @Environment(ServiceManager.self) private var serviceManager

    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(ServiceKind.allCases) { kind in
                ServiceStatusDot(
                    kind: kind,
                    state: serviceManager.serviceState(for: kind)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .popover(isPresented: $showDetail) {
            ServiceDetailPopover()
                .frame(width: 300, height: 200)
        }
        .onTapGesture {
            showDetail.toggle()
        }
    }
}

private struct ServiceStatusDot: View {
    let kind: ServiceKind
    let state: ServiceState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(kind.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(state.displayText)
    }

    private var dotColor: Color {
        switch state {
        case .idle: return .gray
        case .loading: return .yellow
        case .ready: return .green
        case .error: return .red
        case .unloading: return .yellow
        }
    }
}

private struct ServiceDetailPopover: View {
    @Environment(ServiceManager.self) private var serviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Status")
                .font(.headline)

            ForEach(ServiceKind.allCases) { kind in
                HStack {
                    Text(kind.displayName)
                        .font(.body)
                    Spacer()
                    Text(serviceManager.serviceState(for: kind).displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if case .error = serviceManager.serviceState(for: kind) {
                        Button("Retry") {
                            Task {
                                await serviceManager.ensureReady(kind)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}
