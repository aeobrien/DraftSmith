import Foundation

struct EmailGenerationRequest: Sendable {
    let recipientContext: String
    let goal: String
    let keyFacts: String
    let axes: PreferenceAxes

    init(
        recipientContext: String = "",
        goal: String,
        keyFacts: String = "",
        axes: PreferenceAxes = .default
    ) {
        self.recipientContext = recipientContext
        self.goal = goal
        self.keyFacts = keyFacts
        self.axes = axes
    }
}
