import Foundation
import SwiftData

@Model
final class ReviewSession {
    var id: UUID
    var documentURL: String
    var pagesVisitedData: Data? // JSON-encoded [Int]
    var totalPages: Int
    var startedAt: Date
    var lastActiveAt: Date
    var profileID: UUID?

    init(
        id: UUID = UUID(),
        documentURL: String,
        totalPages: Int,
        profileID: UUID? = nil
    ) {
        self.id = id
        self.documentURL = documentURL
        self.pagesVisitedData = try? JSONEncoder().encode([Int]())
        self.totalPages = totalPages
        self.startedAt = Date()
        self.lastActiveAt = Date()
        self.profileID = profileID
    }

    var pagesVisited: Set<Int> {
        get {
            guard let data = pagesVisitedData,
                  let pages = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return Set(pages)
        }
        set {
            pagesVisitedData = try? JSONEncoder().encode(Array(newValue))
            lastActiveAt = Date()
        }
    }

    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesVisited.count) / Double(totalPages)
    }
}
