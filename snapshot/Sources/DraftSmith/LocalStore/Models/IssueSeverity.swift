import Foundation

enum IssueSeverity: String, Codable, Sendable, CaseIterable {
    case warning
    case info

    var displayName: String {
        switch self {
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }

    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
}
