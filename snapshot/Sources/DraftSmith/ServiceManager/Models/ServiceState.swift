import Foundation

enum ServiceState: Sendable, Equatable {
    case idle
    case loading(progress: Double)
    case ready
    case error(String)
    case unloading

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .loading(let progress):
            if progress > 0 {
                return "Loading (\(Int(progress * 100))%)"
            }
            return "Loading..."
        case .ready: return "Ready"
        case .error(let message): return "Error: \(message)"
        case .unloading: return "Unloading..."
        }
    }

    var statusColor: String {
        switch self {
        case .idle: return "gray"
        case .loading: return "yellow"
        case .ready: return "green"
        case .error: return "red"
        case .unloading: return "yellow"
        }
    }
}
