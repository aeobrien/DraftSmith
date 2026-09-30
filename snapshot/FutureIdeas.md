# DraftSmith — Future Ideas & Deferred Features

## Bottom Bar: Focus Mode Layout (Option C)

Instead of the current side-by-side layout (issue list | detail pane), explore a stacked vertical layout:

- The issue message + flagged text fills the top portion of the bottom bar
- Suggestions appear below the message
- Actions (Dismiss/Resolve/etc.) are pinned at the very bottom
- The issue list is replaced by a **compact indicator strip** at the top — small dots or severity-coloured chips for each issue, with the current issue highlighted
- Left/right arrow buttons (or arrow keys) to navigate between issues
- The strip acts like a progress bar showing which issues are resolved/dismissed/new

This approach maximises the space given to the current issue and removes the need for a scrollable list entirely. Trade-off: harder to scan and jump to a specific issue by title.

## Screenshot Attachment for Problem Log

Allow users to attach screenshots when reporting problems:
- Cmd+Shift+4 creates a screenshot on the clipboard or as a file
- Add a "Paste Screenshot" or drag-and-drop target in the problem log chat
- Embed the image in the exported report as a base64 data URL or as a separate file in a zip export
- Would help significantly for UI-related bug reports

## Inline Popover Enhancements (Post-MVP)

Once basic inline popovers are working, consider:
- Hover preview (lighter, smaller) vs click for full detail
- Keyboard navigation between inline markers (Tab/Shift+Tab)
- Animated underline drawing as issues are detected
- Grouping overlapping issues into a single popover with tabs
