import SwiftUI

enum KeyboardShortcuts {
    // Check Engine
    static let checkSelection = KeyboardShortcut("c", modifiers: [.command, .shift])

    // Annotations
    static let createComment = KeyboardShortcut(.return, modifiers: .command)

    // Voice Notes
    static let recordVoiceNote = KeyboardShortcut(.space, modifiers: [.control, .option, .command])

    // Issue Navigation
    static let nextIssue = KeyboardShortcut("]", modifiers: .command)
    static let previousIssue = KeyboardShortcut("[", modifiers: .command)

    // Suggestion Actions
    static let acceptSuggestion = KeyboardShortcut(.return, modifiers: [])

    // Rewrite Controls
    static let makeMoreDirect = KeyboardShortcut(.rightArrow, modifiers: .command)
    static let soften = KeyboardShortcut(.leftArrow, modifiers: .command)
    static let regenerateVariants = KeyboardShortcut("r", modifiers: .command)

    // Bottom Bar
    static let toggleBottomBar = KeyboardShortcut("b", modifiers: .command)
}
