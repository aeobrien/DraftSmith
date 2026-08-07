import Foundation

struct EmailDraft: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let axes: VariantAxes
    let body: String
}
