import Foundation

struct VariantAxes: Codable, Sendable, Equatable {
    let directness: Double
    let brevity: Double
    let formality: Double
    let rewriteVsComment: Double

    enum CodingKeys: String, CodingKey {
        case directness
        case brevity
        case formality
        case rewriteVsComment = "rewrite_vs_comment"
    }
}

struct CommentVariant: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let axes: VariantAxes
    let text: String
}
