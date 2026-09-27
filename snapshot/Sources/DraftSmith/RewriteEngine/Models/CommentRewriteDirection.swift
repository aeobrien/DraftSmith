import Foundation

enum CommentRewriteDirection: Sendable {
    case softer
    case moreDirect
    case polished
    case custom(String)

    var promptInstruction: String {
        switch self {
        case .softer:
            return """
            Rewrite this comment to be softer and more diplomatic. Keep the core message \
            but use gentler phrasing, more hedging language, and a warmer tone. \
            Avoid sounding confrontational or critical.
            """
        case .moreDirect:
            return """
            Rewrite this comment to be more direct and concise. Remove hedging language, \
            unnecessary qualifiers, and get straight to the point. Be clear and assertive \
            while remaining professional.
            """
        case .polished:
            return """
            Polish this editorial comment for clarity and professionalism. \
            Preserve the original meaning and tone but improve phrasing.
            """
        case .custom(let prompt):
            return "Rewrite this comment according to the following instruction: \(prompt)"
        }
    }

    var label: String {
        switch self {
        case .softer: return "Softer"
        case .moreDirect: return "More Direct"
        case .polished: return "Polished"
        case .custom: return "Custom"
        }
    }
}
