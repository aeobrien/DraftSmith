import Foundation

enum IssueStatus: String, Codable, Sendable, CaseIterable {
    case new
    case resolved
    case dismissed

    var displayName: String {
        switch self {
        case .new: return "Unresolved"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }

    var iconName: String {
        switch self {
        case .new: return "exclamationmark.circle"
        case .resolved: return "checkmark.circle"
        case .dismissed: return "xmark.circle"
        }
    }
}
