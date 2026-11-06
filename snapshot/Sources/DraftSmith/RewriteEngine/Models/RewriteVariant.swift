import Foundation

struct RewriteVariant: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let axes: VariantAxes
    let text: String
    let diffSummary: String?

    enum CodingKeys: String, CodingKey {
        case id, label, axes, text
        case diffSummary = "diff_summary"
    }
}
