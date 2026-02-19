import Foundation

enum DiffSegment: Identifiable, Sendable, Codable, Equatable {
    case unchanged(String)
    case deleted(String)
    case inserted(String)

    var id: String {
        switch self {
        case .unchanged(let text): return "u:\(text)"
        case .deleted(let text): return "d:\(text)"
        case .inserted(let text): return "i:\(text)"
        }
    }

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
