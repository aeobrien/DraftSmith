import Foundation

/// Tracks undoable/redoable actions for annotation and issue mutations.
@Observable
@MainActor
final class UndoHistory {

    // MARK: - Action Types

    enum ActionType: String, Sendable {
        case commentEdited
        case suggestionAccepted
        case suggestionIgnored
        case issueResolved
        case issueDismissed
    }

    struct UndoAction: Identifiable, Sendable {
        let id: UUID
        let type: ActionType
        let annotationID: UUID
        let previousText: String
        let newText: String
        let timestamp: Date

        init(
            type: ActionType,
            annotationID: UUID,
            previousText: String,
            newText: String,
            timestamp: Date = Date()
        ) {
            self.id = UUID()
            self.type = type
            self.annotationID = annotationID
            self.previousText = previousText
            self.newText = newText
            self.timestamp = timestamp
        }
    }

    // MARK: - State

    private(set) var undoStack: [UndoAction] = []
    private(set) var redoStack: [UndoAction] = []

    private let maxEntries = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var undoDescription: String? {
        guard let action = undoStack.last else { return nil }
        return descriptionForAction(action, prefix: "Undo")
    }

    var redoDescription: String? {
        guard let action = redoStack.last else { return nil }
        return descriptionForAction(action, prefix: "Redo")
    }

    // MARK: - Recording

    func record(_ action: UndoAction) {
        undoStack.append(action)
        redoStack.removeAll()

        // Cap at maxEntries
        if undoStack.count > maxEntries {
            undoStack.removeFirst(undoStack.count - maxEntries)
        }
    }

    func recordCommentEdit(annotationID: UUID, previousText: String, newText: String) {
        record(UndoAction(
            type: .commentEdited,
            annotationID: annotationID,
            previousText: previousText,
            newText: newText
        ))
    }

    func recordSuggestionAccepted(annotationID: UUID, previousText: String, newText: String) {
        record(UndoAction(
            type: .suggestionAccepted,
            annotationID: annotationID,
            previousText: previousText,
            newText: newText
        ))
    }

    func recordSuggestionIgnored(annotationID: UUID, dismissedText: String) {
        record(UndoAction(
            type: .suggestionIgnored,
            annotationID: annotationID,
            previousText: dismissedText,
            newText: ""
        ))
    }

    func recordIssueResolved(issueID: UUID) {
        record(UndoAction(
            type: .issueResolved,
            annotationID: issueID,
            previousText: "",
            newText: ""
        ))
    }

    func recordIssueDismissed(issueID: UUID) {
        record(UndoAction(
            type: .issueDismissed,
            annotationID: issueID,
            previousText: "",
            newText: ""
        ))
    }

    // MARK: - Undo / Redo

    /// Pops the last undo action and returns it so the caller can apply the reversal.
    func popUndo() -> UndoAction? {
        guard let action = undoStack.popLast() else { return nil }
        redoStack.append(action)
        return action
    }

    /// Pops the last redo action and returns it so the caller can re-apply.
    func popRedo() -> UndoAction? {
        guard let action = redoStack.popLast() else { return nil }
        undoStack.append(action)
        return action
    }

    /// Clears all history (e.g. when a new document is opened).
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Helpers

    private func descriptionForAction(_ action: UndoAction, prefix: String) -> String {
        switch action.type {
        case .commentEdited:
            return "\(prefix) Comment Edit"
        case .suggestionAccepted:
            return "\(prefix) Accept Suggestion"
        case .suggestionIgnored:
            return "\(prefix) Dismiss Suggestion"
        case .issueResolved:
            return "\(prefix) Resolve Issue"
        case .issueDismissed:
            return "\(prefix) Dismiss Issue"
        }
    }
}
