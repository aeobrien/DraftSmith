import Foundation

struct TerminologyEntry: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var preferred: String
    var rejected: String
    var note: String?

    init(preferred: String, rejected: String, note: String? = nil) {
        self.preferred = preferred
        self.rejected = rejected
        self.note = note
    }
}
