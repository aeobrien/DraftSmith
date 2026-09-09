import Foundation

enum DiffSegment: Sendable, Codable, Equatable {
    case unchanged(String)
    case deleted(String)
    case inserted(String)

    var text: String {
        switch self {
        case .unchanged(let text), .deleted(let text), .inserted(let text):
            return text
        }
    }

    var isUnchanged: Bool {
        if case .unchanged = self { return true }
        return false
    }

    var isDeleted: Bool {
        if case .deleted = self { return true }
        return false
    }

    var isInserted: Bool {
        if case .inserted = self { return true }
        return false
    }
}
