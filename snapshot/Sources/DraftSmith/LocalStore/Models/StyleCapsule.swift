import Foundation
import SwiftData

@Model
final class StyleCapsule {
    var id: UUID
    var capsuleText: String
    var keyTendenciesData: Data? // JSON-encoded [String]
    var tokenCount: Int
    var isActive: Bool
    var isPendingApproval: Bool
    var createdAt: Date
    var activatedAt: Date?

    init(
        id: UUID = UUID(),
        capsuleText: String = "",
        keyTendencies: [String] = [],
        tokenCount: Int = 0,
        isActive: Bool = false,
        isPendingApproval: Bool = false
    ) {
        self.id = id
        self.capsuleText = capsuleText
        self.keyTendenciesData = try? JSONEncoder().encode(keyTendencies)
        self.tokenCount = tokenCount
        self.isActive = isActive
        self.isPendingApproval = isPendingApproval
        self.createdAt = Date()
    }

    var keyTendencies: [String] {
        get {
            guard let data = keyTendenciesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            keyTendenciesData = try? JSONEncoder().encode(newValue)
        }
    }
}
