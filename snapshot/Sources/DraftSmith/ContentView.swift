import SwiftUI
import PDFKit
import AppKit

struct ContentView: View {
    @Environment(PDFDocumentManager.self) private var documentManager
    @Environment(ServiceManager.self) private var serviceManager
    @Environment(IssueManager.self) private var issueManager
    @Environment(CheckEngine.self) private var checkEngine
    @Environment(RewriteEngine.self) private var rewriteEngine
    @Environment(ReviewProgressTracker.self) private var progressTracker
    @Environment(VoiceNotePipeline.self) private var voiceNotePipeline
    @Environment(EmailStudioService.self) private var emailStudioService
    @Environment(StyleMemoryManager.self) private var styleMemoryManager
    @Environment(ProjectProfileManager.self) private var profileManager
    @Environment(UndoHistory.self) private var undoHistory

    @State private var selectedIssue: Issue?
    @State private var issues: [Issue] = []
    @State private var annotations: [DSAnnotation] = []
    @State private var showEmailStudio = false
    @State private var showVoiceNotePanel = false
    @State private var showCommentEditor = false
    @State private var newCommentText = ""
    @State private var rewriteAnnotation: DSAnnotation?
    @State private var rewriteDirection: CommentRewriteDirection = .softer
    @State private var editingAnnotation: DSAnnotation?
    @State private var editCommentText = ""
    @State private var issueEditorCommentText = ""
    @State private var issueEditorIssue: Issue?
    @State private var showIssueCommentEditor = false
    @State private var showBottomBar: Bool = true
    @State private var isQuickRecording = false
    @State private var quickRecorder = AudioRecorder()
    @State private var quickRecordingSelectionText: String?
    @State private var quickRecordingPageIndex: Int?
    @State private var eventMonitor: Any?
    @State private var showProblemLog = false
    @State private var issuePopover: NSPopover?
    @State private var showOpenRecentUnsavedAlert = false
    @State private var pendingOpenURL: URL?
    @State private var copilotExportAlert: String?
    @State private var showCopilotExportAlert = false
    @State private var copilotImportAlert: String?
    @State private var showCopilotImportAlert = false

    private let commentPanelWidth: CGFloat = 260

    var body: some View {
        mainLayout
            .toolbar { mainToolbar }
            .modifier(SheetModifiers(
                showEmailStudio: $showEmailStudio,
                showVoiceNotePanel: $showVoiceNotePanel,
                showProblemLog: $showProblemLog,
                showCommentEditor: $showCommentEditor,
                newCommentText: $newCommentText,
                rewriteAnnotation: $rewriteAnnotation,
                rewriteDirection: rewriteDirection,
                editingAnnotation: $editingAnnotation,
                editCommentText: $editCommentText,
                showIssueCommentEditor: $showIssueCommentEditor,
                issueEditorCommentText: $issueEditorCommentText,
                issueEditorIssue: $issueEditorIssue,
                documentManager: documentManager,
                issueManager: issueManager,
                undoHistory: undoHistory,
                onRefreshAnnotations: { refreshAnnotations() },
                onRefreshIssues: { refreshIssues() },
                onAdvanceToNextUnresolved: { advanceToNextUnresolved() },
                onRequestBackgroundSuggestion: { requestBackgroundSuggestion(for: $0) }
            ))
            .onAppear {
                refreshIssues()
                refreshAnnotations()
                installVKeyMonitor()
            }
            .onDisappear {
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    eventMonitor = nil
                }
            }
            .onChange(of: documentManager.documentURL) { _, _ in
                selectedIssue = nil
                documentManager.issueOutlineBounds = nil
                documentManager.issueOutlinePageIndex = nil
                documentManager.issueOverlayInfo = nil
                documentManager.selectedAnnotationID = nil
                undoHistory.clear()
                refreshIssues()
                updateInlineMarkers()
                refreshAnnotations()
            }
            .onChange(of: selectedIssue?.id) { _, newValue in
                if newValue == nil {
                    documentManager.issueOutlineBounds = nil
                    documentManager.issueOutlinePageIndex = nil
                    documentManager.issueOverlayInfo = nil
                }
            }
            .onChange(of: documentManager.currentSelection?.string) { _, _ in
                if isQuickRecording {
                    stopQuickRecording()
                }
            }
            .onChange(of: documentManager.currentPageIndex) { _, newIndex in
                progressTracker.markPageVisited(newIndex)
                updateProgressCounts()
            }
            .focusedSceneValue(\.documentManager, documentManager)
            .onReceive(NotificationCenter.default.publisher(for: .saveAsRequested)) { _ in
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = documentManager.documentURL?.lastPathComponent ?? "Untitled.pdf"
                if panel.runModal() == .OK, let url = panel.url {
                    try? documentManager.saveAs(url: url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openRecentRequested)) { notification in
                guard let url = notification.userInfo?["url"] as? URL else { return }
                if documentManager.isModified {
                    pendingOpenURL = url
                    showOpenRecentUnsavedAlert = true
                } else {
                    openRecentDocument(url: url)
                }
            }
            .alert("Unsaved Changes", isPresented: $showOpenRecentUnsavedAlert) {
                Button("Save and Open") {
                    try? documentManager.save()
                    if let url = pendingOpenURL {
                        openRecentDocument(url: url)
                    }
                }
                Button("Discard and Open", role: .destructive) {
                    if let url = pendingOpenURL {
                        openRecentDocument(url: url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingOpenURL = nil
                }
            } message: {
                Text("You have unsaved changes. Would you like to save before opening a new file?")
            }
            .alert("Copilot Export", isPresented: $showCopilotExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(copilotExportAlert ?? "")
            }
            .alert("Copilot Import", isPresented: $showCopilotImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(copilotImportAlert ?? "")
            }
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                centerPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showBottomBar {
                    Divider()
                    IssueBottomBarView(
                        issues: issues,
                        selectedIssue: $selectedIssue,
                        onSelectIssue: { handleSelectIssue($0) },
                        onResolveIssue: { handleResolveIssue($0) },
                        onDismissIssue: { handleDismissIssue($0) },
                        onAddAsComment: { handleAddAsComment($0, $1) },
                        onAddNaturalComment: { handleAddNaturalComment($0, $1) },
                        onGenerateNaturalComment: { issue, suggestion in
                            let examples = profileManager.activeProfile?.commentExamples[issue.category ?? ""] ?? []
                            return try? await rewriteEngine.generateIssueComment(
                                category: issue.category ?? "Issue",
                                ruleID: issue.ruleID,
                                flaggedText: issue.selectionText,
                                suggestion: suggestion,
                                message: issue.message,
                                exampleComments: examples
                            )
                        },
                        onEditComment: { handleEditComment($0, $1) },
                        onDismissAllMatchingText: { handleDismissAllMatchingText($0) },
                        onDismissAllMatchingRule: { handleDismissAllMatchingRule($0) },
                        onAddToDictionary: { handleAddToDictionary($0) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showBottomBar)

            Divider()

            commentPanel
                .frame(width: commentPanelWidth)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                withAnimation {
                    showBottomBar.toggle()
                }
            } label: {
                Label("Toggle Issue Bar", systemImage: "rectangle.bottomhalf.filled")
            }
            .keyboardShortcut("b", modifiers: .command)
            .help("Toggle issue bar (Cmd+B)")

            CheckSelectionButton(
                hasSelection: documentManager.currentSelection != nil,
                isChecking: checkEngine.isChecking,
                action: {
                    guard let selection = documentManager.currentSelection,
                          let text = selection.string else { return }
                    Task {
                        _ = try? await checkEngine.checkSelection(
                            text: text,
                            pageIndex: documentManager.currentPageIndex,
                            documentURL: documentManager.documentURL?.absoluteString
                        )
                        refreshIssues()
                        updateInlineMarkers()
                    }
                }
            )

            Button {
                guard documentManager.document != nil else { return }
                Task {
                    _ = try? await checkEngine.checkDocument(
                        document: documentManager.document!,
                        documentURL: documentManager.documentURL?.absoluteString
                    )
                    refreshIssues()
                    updateInlineMarkers()
                }
            } label: {
                if checkEngine.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Check Document", systemImage: "doc.text.magnifyingglass")
                }
            }
            .disabled(documentManager.document == nil || checkEngine.isChecking)
            .help("Check entire document for grammar and style issues")

            Button {
                showVoiceNotePanel = true
            } label: {
                Label("Voice Note", systemImage: "mic")
            }
            .help("Record a voice note")

            Button {
                showProblemLog = true
            } label: {
                Label("Report Problem", systemImage: "exclamationmark.bubble")
            }
            .help("Report a problem with DraftSmith")

            Divider()

            Button {
                performUndo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!undoHistory.canUndo)
            .help(undoHistory.undoDescription ?? "Undo")

            Button {
                performRedo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!undoHistory.canRedo)
            .help(undoHistory.redoDescription ?? "Redo")

            Divider()

            Button {
                guard !annotations.isEmpty else {
                    copilotExportAlert = "No comments to export."
                    showCopilotExportAlert = true
                    return
                }
                let json = CopilotExportService.exportJSON(
                    annotations: annotations,
                    issues: issues
                )
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(json, forType: .string)
                copilotExportAlert = "Copied \(annotations.count) comments to clipboard. Paste into Copilot for rewriting."
                showCopilotExportAlert = true
            } label: {
                Label("Export for Rewrite", systemImage: "square.and.arrow.up")
            }
            .disabled(documentManager.document == nil)
            .help("Export comments as JSON for Copilot rewriting")

            Button {
                guard let json = NSPasteboard.general.string(forType: .string) else {
                    copilotImportAlert = "Clipboard is empty."
                    showCopilotImportAlert = true
                    return
                }
                let result = CopilotExportService.importJSON(
                    json,
                    annotations: annotations,
                    documentManager: documentManager
                )
                if result.total == 0 {
                    copilotImportAlert = "No valid rewrites found in clipboard. Check the JSON format."
                } else {
                    copilotImportAlert = "Imported \(result.matched) of \(result.total) rewrites as suggestions."
                }
                showCopilotImportAlert = true
            } label: {
                Label("Import Rewrites", systemImage: "square.and.arrow.down")
            }
            .disabled(documentManager.document == nil)
            .help("Import Copilot-rewritten comments from clipboard")
        }
    }

    // MARK: - Center Panel (PDF + status bar)

    private var centerPanel: some View {
        VStack(spacing: 0) {
            PDFWorkspaceView(
                onAnnotationsChanged: {
                    refreshAnnotations()
                },
                onIssueAnnotationClicked: { issueID, view, rect in
                    handleIssueAnnotationClicked(issueID: issueID, view: view, rect: rect)
                },
                onCommentAnnotationClicked: { uuid in
                    documentManager.selectedAnnotationID = uuid
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                ReviewProgressView()
                Spacer()
                if isQuickRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Recording\u{2026}")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    documentManager.showIssueOverlay.toggle()
                } label: {
                    Image(systemName: documentManager.showIssueOverlay ? "text.bubble.fill" : "text.bubble")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(documentManager.showIssueOverlay ? "Hide issue overlay" : "Show issue overlay")

                Button {
                    documentManager.showInlineMarkers.toggle()
                    updateInlineMarkers()
                } label: {
                    Image(systemName: documentManager.showInlineMarkers ? "eye" : "eye.slash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(documentManager.showInlineMarkers ? "Hide inline markers" : "Show inline markers")

                ServiceStatusBarView()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.windowBackgroundColor))
        }
    }

    // MARK: - Comment Panel (right)

    private var commentPanel: some View {
        CommentSidebarView(
            annotations: annotations,
            hasSelection: documentManager.currentSelection != nil,
            rewriteSuggestions: documentManager.rewriteSuggestions,
            selectedAnnotationID: documentManager.selectedAnnotationID,
            onNavigateToAnnotation: { annotation in
                documentManager.navigateToIssue(
                    pageIndex: annotation.pageIndex,
                    highlightText: annotation.commentText
                )
            },
            onSelectAnnotation: { annotation in
                documentManager.selectedAnnotationID = annotation.id
            },
            onAddComment: {
                newCommentText = ""
                showCommentEditor = true
            },
            onAddVoiceComment: { transcription in
                if let annotation = documentManager.createAnnotation(comment: transcription, source: .voiceNote) {
                    requestBackgroundSuggestion(for: annotation)
                }
                refreshAnnotations()
            },
            onDeleteAnnotation: { annotation in
                guard let document = documentManager.document else { return }
                documentManager.annotationService.removeAnnotation(
                    from: document,
                    annotation: annotation
                )
                documentManager.clearSuggestion(for: annotation.id)
                documentManager.markModified()
                refreshAnnotations()
            },
            onRewriteAnnotation: { annotation, direction in
                rewriteDirection = direction
                rewriteAnnotation = annotation
            },
            onRevertAnnotation: { annotation in
                _ = documentManager.revertAnnotation(annotation: annotation)
                refreshAnnotations()
            },
            onEditAnnotation: { annotation in
                editCommentText = annotation.commentText
                editingAnnotation = annotation
            },
            onApplySuggestion: { annotation, suggestion in
                undoHistory.recordSuggestionAccepted(
                    annotationID: annotation.id,
                    previousText: annotation.commentText,
                    newText: suggestion
                )
                _ = documentManager.updateAnnotationText(
                    annotation: annotation,
                    newText: suggestion
                )
                documentManager.clearSuggestion(for: annotation.id)
                refreshAnnotations()
            },
            onDismissSuggestion: { annotation in
                if let dismissed = documentManager.rewriteSuggestions[annotation.id] {
                    undoHistory.recordSuggestionIgnored(
                        annotationID: annotation.id,
                        dismissedText: dismissed
                    )
                }
                documentManager.clearSuggestion(for: annotation.id)
            },
            onRequestRewrite: { annotation in
                requestBackgroundSuggestion(for: annotation)
            }
        )
    }

    // MARK: - Issue Callbacks

    private func handleSelectIssue(_ issue: Issue) {
        // Guard against redundant calls from SwiftUI re-rendering
        guard selectedIssue?.id != issue.id else { return }

        selectedIssue = issue
        documentManager.navigateToIssue(
            pageIndex: issue.pageIndex,
            highlightText: issue.selectionText,
            highlightOffset: issue.textOffset
        )
        // Try to reuse cached bounds from inline markers (avoids expensive findString)
        if let cached = documentManager.issueUnderlineLocations.first(where: { $0.issueID == issue.id }) {
            documentManager.issueOutlineBounds = cached.bounds
            documentManager.issueOutlinePageIndex = cached.pageIndex
        } else if let document = documentManager.document {
            // Try offset-based precise selection first (avoids "st" in "August" vs "1st" problem)
            var found = false
            if let offset = issue.textOffset,
               let length = issue.textLength,
               let page = document.page(at: issue.pageIndex),
               let pageText = page.string {
                // Find all occurrences of the flagged text on this page
                let searchText = issue.selectionText
                let nsPageText = pageText as NSString
                var searchRange = NSRange(location: 0, length: nsPageText.length)
                var occurrences: [(range: NSRange, distance: Int)] = []

                while searchRange.location < nsPageText.length {
                    let foundRange = nsPageText.range(of: searchText, options: .caseInsensitive, range: searchRange)
                    if foundRange.location == NSNotFound { break }
                    let distance = abs(foundRange.location - offset)
                    occurrences.append((range: foundRange, distance: distance))
                    searchRange.location = foundRange.location + 1
                    searchRange.length = nsPageText.length - searchRange.location
                }

                // Pick the occurrence closest to the stored offset
                if let closest = occurrences.min(by: { $0.distance < $1.distance }) {
                    if let selection = page.selection(for: NSRange(location: closest.range.location, length: closest.range.length)) {
                        let bounds = selection.bounds(for: page)
                        documentManager.issueOutlineBounds = bounds
                        documentManager.issueOutlinePageIndex = issue.pageIndex
                        found = true
                    }
                }
            }

            if !found {
                // Fallback: search for the text across the document
                if let selection = document.findString(issue.selectionText, withOptions: [])
                    .first(where: { sel in
                        guard let page = sel.pages.first else { return false }
                        return document.index(for: page) == issue.pageIndex
                    }) {
                    let bounds = selection.bounds(for: selection.pages.first!)
                    documentManager.issueOutlineBounds = bounds
                    documentManager.issueOutlinePageIndex = issue.pageIndex
                } else {
                    documentManager.issueOutlineBounds = nil
                    documentManager.issueOutlinePageIndex = nil
                }
            }
        }
        // Set overlay info for the selected issue
        documentManager.issueOverlayInfo = IssueOverlayInfo(
            message: issue.message,
            category: issue.category,
            selectionText: issue.selectionText,
            suggestion: issue.suggestionsList.first
        )
    }

    private func handleResolveIssue(_ issue: Issue) {
        undoHistory.recordIssueResolved(issueID: issue.id)
        issueManager.resolveIssue(issue)
        removeInlineMarker(for: issue.id)
        // Update in-memory — no DB re-fetch needed
        updateProgressCounts()
        advanceToNextUnresolved()
    }

    private func handleDismissIssue(_ issue: Issue) {
        undoHistory.recordIssueDismissed(issueID: issue.id)
        issueManager.dismissIssue(issue)
        removeInlineMarker(for: issue.id)
        // Update in-memory — no DB re-fetch needed
        updateProgressCounts()
        advanceToNextUnresolved()
    }


    private func handleDismissAllMatchingText(_ issue: Issue) {
        let matchingIDs = Set(issues.filter { $0.selectionText == issue.selectionText && $0.issueStatus == .new }.map(\.id))
        for id in matchingIDs {
            undoHistory.recordIssueDismissed(issueID: id)
        }
        issueManager.dismissAllMatching(
            selectionText: issue.selectionText,
            documentURL: documentManager.documentURL?.absoluteString
        )
        removeInlineMarkers(where: { matchingIDs.contains($0) })
        // Update in-memory — no DB re-fetch needed
        updateProgressCounts()
        advanceToNextUnresolved()
    }

    private func handleDismissAllMatchingRule(_ issue: Issue) {
        guard let ruleID = issue.ruleID else { return }
        let matchingIDs = Set(issues.filter { $0.ruleID == ruleID && $0.issueStatus == .new }.map(\.id))
        for id in matchingIDs {
            undoHistory.recordIssueDismissed(issueID: id)
        }
        issueManager.dismissAllByRule(
            ruleID: ruleID,
            documentURL: documentManager.documentURL?.absoluteString
        )
        removeInlineMarkers(where: { matchingIDs.contains($0) })
        // Update in-memory — no DB re-fetch needed
        updateProgressCounts()
        advanceToNextUnresolved()
    }

    private func handleAddToDictionary(_ issue: Issue) {
        guard let profile = profileManager.activeProfile else { return }
        var dict = profile.customDictionary
        let word = issue.selectionText
        if !dict.contains(where: { $0.lowercased() == word.lowercased() }) {
            dict.append(word)
            profile.customDictionary = dict
        }
        let matchingIDs = Set(issues.filter { $0.selectionText == word && $0.issueStatus == .new }.map(\.id))
        for id in matchingIDs {
            undoHistory.recordIssueDismissed(issueID: id)
        }
        issueManager.dismissAllMatching(
            selectionText: word,
            documentURL: documentManager.documentURL?.absoluteString
        )
        removeInlineMarkers(where: { matchingIDs.contains($0) })
        // Update in-memory — no DB re-fetch needed
        updateProgressCounts()
        advanceToNextUnresolved()
    }

    private func handleAddAsComment(_ issue: Issue, _ text: String) {
        let annotation = documentManager.createAnnotationForIssue(
            comment: text,
            source: .languageTool,
            pageIndex: issue.pageIndex,
            selectionText: issue.selectionText
        )
        undoHistory.recordIssueResolved(issueID: issue.id)
        issueManager.resolveIssue(issue, annotationUUID: annotation?.id)
        removeInlineMarker(for: issue.id)
        updateProgressCounts()
        refreshAnnotations()
        advanceToNextUnresolved()
    }

    private func handleAddNaturalComment(_ issue: Issue, _ suggestion: String) {
        let placeholder = "Generating comment\u{2026}"
        guard let annotation = documentManager.createAnnotationForIssue(
            comment: placeholder,
            source: .languageTool,
            pageIndex: issue.pageIndex,
            selectionText: issue.selectionText
        ) else {
            return
        }
        let annotationID = annotation.id
        let annotationPageIndex = annotation.pageIndex
        let annotationBounds = annotation.selectionBounds
        let annotationMetadata = annotation.metadata
        undoHistory.recordIssueResolved(issueID: issue.id)
        issueManager.resolveIssue(issue, annotationUUID: annotationID)
        removeInlineMarker(for: issue.id)
        updateProgressCounts()
        refreshAnnotations()
        advanceToNextUnresolved()
        let category = issue.category ?? "Issue"
        let ruleID = issue.ruleID
        let flaggedText = issue.selectionText
        let message = issue.message
        let examples = profileManager.activeProfile?.commentExamples[issue.category ?? ""] ?? []
        Task {
            let comment = try? await rewriteEngine.generateIssueComment(
                category: category,
                ruleID: ruleID,
                flaggedText: flaggedText,
                suggestion: suggestion,
                message: message,
                exampleComments: examples
            )
            let finalText = (comment?.isEmpty == false) ? comment! : "\(category): \(suggestion)"
            let stubAnnotation = DSAnnotation(
                id: annotationID,
                commentText: placeholder,
                pageIndex: annotationPageIndex,
                selectionBounds: annotationBounds,
                metadata: annotationMetadata
            )
            _ = documentManager.updateAnnotationText(
                annotation: stubAnnotation,
                newText: finalText
            )
            // Don't call requestBackgroundSuggestion here — this comment was
            // already LLM-generated, no need to polish/rewrite it again.
            refreshAnnotations()
        }
    }

    private func handleEditComment(_ issue: Issue, _ text: String) {
        issueEditorCommentText = text
        issueEditorIssue = issue
        showIssueCommentEditor = true
    }

    // MARK: - V Key Quick Recording

    private func installVKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.charactersIgnoringModifiers == "v",
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] else {
                return event
            }
            // Don't capture V when typing in text fields
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }
            if isQuickRecording {
                stopQuickRecording()
                return nil
            } else if documentManager.currentSelection != nil {
                startQuickRecording()
                return nil
            }
            return event
        }
    }

    private func startQuickRecording() {
        quickRecordingSelectionText = documentManager.currentSelection?.string
        quickRecordingPageIndex = documentManager.currentPageIndex
        do {
            try quickRecorder.startRecording(annotationUUID: UUID())
            isQuickRecording = true
        } catch {
            // Recording failed to start — no user-facing action needed
        }
    }

    private func stopQuickRecording() {
        guard isQuickRecording else { return }
        isQuickRecording = false
        // Capture saved values before any async work — these were recorded at start time
        let savedText = quickRecordingSelectionText
        let savedPage = quickRecordingPageIndex ?? 0
        quickRecordingSelectionText = nil
        quickRecordingPageIndex = nil
        guard let recording = quickRecorder.stopRecording() else { return }
        Task {
            let result = try? await serviceManager.transcriptionService.transcribe(audioURL: recording.url)
            guard let comment = result?.text, !comment.isEmpty else { return }
            // Use findString to locate the original text — do NOT use currentSelection
            // because the user may have already selected different text.
            var annotation: DSAnnotation?
            if let savedText, let document = documentManager.document,
               let page = document.page(at: savedPage),
               let selection = document.findString(savedText, withOptions: [])
                .first(where: { $0.pages.contains(page) }) {
                annotation = documentManager.annotationService.createHighlightWithComment(
                    on: document,
                    selection: selection,
                    comment: comment,
                    source: .voiceNote
                )
                if annotation != nil { documentManager.markModified() }
            } else {
                annotation = documentManager.createAnnotation(comment: comment, source: .voiceNote)
            }
            refreshAnnotations()
            if let annotation {
                requestBackgroundSuggestion(for: annotation)
            }
        }
    }

    // MARK: - Undo / Redo

    private func performUndo() {
        guard let action = undoHistory.popUndo() else { return }
        applyUndoAction(action, isRedo: false)
    }

    private func performRedo() {
        guard let action = undoHistory.popRedo() else { return }
        applyUndoAction(action, isRedo: true)
    }

    private func applyUndoAction(_ action: UndoHistory.UndoAction, isRedo: Bool) {
        switch action.type {
        case .commentEdited, .suggestionAccepted:
            // Find the annotation and revert/re-apply text
            if let annotation = annotations.first(where: { $0.id == action.annotationID }) {
                let targetText = isRedo ? action.newText : action.previousText
                _ = documentManager.updateAnnotationText(
                    annotation: annotation,
                    newText: targetText
                )
                refreshAnnotations()
            }

        case .suggestionIgnored:
            if isRedo {
                // Re-dismiss the suggestion
                documentManager.clearSuggestion(for: action.annotationID)
            } else {
                // Restore the dismissed suggestion
                documentManager.rewriteSuggestions[action.annotationID] = action.previousText
            }

        case .issueResolved:
            if isRedo {
                // Re-resolve
                if let issue = issues.first(where: { $0.id == action.annotationID }) {
                    issueManager.resolveIssue(issue)
                    removeInlineMarker(for: issue.id)
                    updateProgressCounts()
                }
            } else {
                // Un-resolve: set back to new
                if let issue = issues.first(where: { $0.id == action.annotationID }) {
                    issue.issueStatus = .new
                    refreshIssues()
                    updateInlineMarkers()
                }
            }

        case .issueDismissed:
            if isRedo {
                // Re-dismiss
                if let issue = issues.first(where: { $0.id == action.annotationID }) {
                    issueManager.dismissIssue(issue)
                    removeInlineMarker(for: issue.id)
                    updateProgressCounts()
                }
            } else {
                // Un-dismiss: set back to new
                if let issue = issues.first(where: { $0.id == action.annotationID }) {
                    issue.issueStatus = .new
                    refreshIssues()
                    updateInlineMarkers()
                }
            }
        }
    }

    // MARK: - Data

    private func refreshIssues() {
        guard let url = documentManager.documentURL?.absoluteString else {
            issues = []
            documentManager.issueUnderlineLocations = []
            return
        }
        issues = issueManager.fetchIssues(for: url)
        updateProgressCounts()
    }

    private func refreshAnnotations() {
        annotations = documentManager.allAnnotations()
    }

    private func requestBackgroundSuggestion(for annotation: DSAnnotation) {
        let text = annotation.commentText
        let annotationID = annotation.id
        // Skip placeholder text
        guard !text.isEmpty, !text.hasPrefix("Generating comment") else { return }

        // Check if LLM is ready before attempting — don't hang waiting
        let llmState = serviceManager.serviceState(for: .llm)
        guard llmState.isReady else { return }

        Task {
            do {
                let polished = try await rewriteEngine.polishComment(commentText: text)
                // Only suggest if meaningfully different from the original
                guard polished.lowercased() != text.lowercased() else { return }
                documentManager.rewriteSuggestions[annotationID] = polished
            } catch {
                // Fallback: use rewriteComment (JSON-based) which may work for some inputs
                do {
                    let variants = try await rewriteEngine.rewriteComment(
                        commentText: text,
                        direction: .softer
                    )
                    if let best = variants.first, best.text.lowercased() != text.lowercased() {
                        documentManager.rewriteSuggestions[annotationID] = best.text
                    }
                } catch {
                    // Suggestion generation failed — non-critical, silently continue
                }
            }
        }
    }

    private func advanceToNextUnresolved() {
        let unresolvedIssues = issues.filter { $0.issueStatus == .new }
        if let first = unresolvedIssues.first {
            handleSelectIssue(first)
        } else {
            selectedIssue = nil
            documentManager.issueOutlineBounds = nil
            documentManager.issueOutlinePageIndex = nil
            documentManager.issueOverlayInfo = nil
        }
    }

    private func openRecentDocument(url: URL) {
        pendingOpenURL = nil
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        try? documentManager.open(url: url)
        RecentDocumentsManager.shared.addDocument(url: url)
        refreshIssues()
        refreshAnnotations()
    }

    private func updateInlineMarkers() {
        if documentManager.showInlineMarkers {
            documentManager.issueUnderlineLocations = documentManager.resolveIssueLocations(for: issues)
        } else {
            documentManager.issueUnderlineLocations = []
        }
    }

    /// Incrementally remove a dismissed/resolved issue from inline markers without full recalculation.
    private func removeInlineMarker(for issueID: UUID) {
        documentManager.issueUnderlineLocations.removeAll { $0.issueID == issueID }
    }

    /// Remove inline markers for all issues matching a predicate (e.g. same text or rule).
    private func removeInlineMarkers(where predicate: (UUID) -> Bool) {
        documentManager.issueUnderlineLocations.removeAll { predicate($0.issueID) }
    }

    private func handleIssueAnnotationClicked(issueID: UUID, view: NSView, rect: CGRect) {
        guard let issue = issues.first(where: { $0.id == issueID }) else { return }

        issuePopover?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 300)

        let popoverView = IssuePopoverView(
            issue: issue,
            onDismiss: { [weak popover] in
                popover?.close()
                handleDismissIssue(issue)
            },
            onResolve: { [weak popover] in
                popover?.close()
                handleResolveIssue(issue)
            },
            onAddAsComment: { [weak popover] text in
                popover?.close()
                handleAddAsComment(issue, text)
            },
            onAddNaturalComment: { [weak popover] suggestion in
                popover?.close()
                handleAddNaturalComment(issue, suggestion)
            },
            onEditComment: { [weak popover] text in
                popover?.close()
                handleEditComment(issue, text)
            },
            onDismissAllMatchingText: { [weak popover] in
                popover?.close()
                handleDismissAllMatchingText(issue)
            },
            onDismissAllMatchingRule: { [weak popover] in
                popover?.close()
                handleDismissAllMatchingRule(issue)
            },
            onAddToDictionary: { [weak popover] in
                popover?.close()
                handleAddToDictionary(issue)
            }
        )

        popover.contentViewController = NSHostingController(rootView: popoverView)
        popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
        issuePopover = popover
    }

    private func updateProgressCounts() {
        // Compute counts from in-memory issues array — avoids expensive SwiftData fetch
        let newCount = issues.filter { $0.issueStatus == .new }.count
        let resolvedCount = issues.filter { $0.issueStatus == .resolved }.count
        let dismissedCount = issues.filter { $0.issueStatus == .dismissed }.count
        progressTracker.updateIssueCounts(
            total: issues.count,
            new: newCount,
            resolved: resolvedCount,
            dismissed: dismissedCount
        )
        progressTracker.setTotalPages(documentManager.pageCount)
    }
}

// MARK: - Sheet Modifiers (extracted to reduce body complexity)

private struct SheetModifiers: ViewModifier {
    @Binding var showEmailStudio: Bool
    @Binding var showVoiceNotePanel: Bool
    @Binding var showProblemLog: Bool
    @Binding var showCommentEditor: Bool
    @Binding var newCommentText: String
    @Binding var rewriteAnnotation: DSAnnotation?
    let rewriteDirection: CommentRewriteDirection
    @Binding var editingAnnotation: DSAnnotation?
    @Binding var editCommentText: String
    @Binding var showIssueCommentEditor: Bool
    @Binding var issueEditorCommentText: String
    @Binding var issueEditorIssue: Issue?
    let documentManager: PDFDocumentManager
    let issueManager: IssueManager
    let undoHistory: UndoHistory
    let onRefreshAnnotations: () -> Void
    let onRefreshIssues: () -> Void
    let onAdvanceToNextUnresolved: () -> Void
    let onRequestBackgroundSuggestion: (DSAnnotation) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showEmailStudio) {
                EmailStudioView()
                    .frame(minWidth: 500, minHeight: 400)
            }
            .sheet(isPresented: $showProblemLog) {
                ProblemLogView()
                    .frame(minWidth: 550, minHeight: 450)
            }
            .sheet(isPresented: $showVoiceNotePanel) {
                VoiceNotePanelView(
                    passage: documentManager.currentSelection?.string ?? "",
                    axes: .default,
                    onUseAsComment: { variant in
                        if let annotation = documentManager.createAnnotation(comment: variant.text, source: .manual) {
                            onRequestBackgroundSuggestion(annotation)
                        }
                        showVoiceNotePanel = false
                        onRefreshAnnotations()
                    }
                )
                .frame(width: 400, height: 350)
            }
            .sheet(isPresented: $showCommentEditor) {
                CommentEditorView(
                    commentText: $newCommentText,
                    onSave: { text in
                        if let annotation = documentManager.createAnnotation(comment: text, source: .manual) {
                            onRequestBackgroundSuggestion(annotation)
                        }
                        showCommentEditor = false
                        onRefreshAnnotations()
                    },
                    onCancel: {
                        showCommentEditor = false
                    }
                )
                .frame(width: 400, height: 250)
            }
            .sheet(item: $rewriteAnnotation) { annotation in
                CommentRewriteSheet(
                    annotation: annotation,
                    direction: rewriteDirection,
                    onApply: { annotation, newText in
                        _ = documentManager.updateAnnotationText(
                            annotation: annotation,
                            newText: newText
                        )
                        rewriteAnnotation = nil
                        onRefreshAnnotations()
                    },
                    onCancel: {
                        rewriteAnnotation = nil
                    }
                )
                .frame(width: 500, height: 500)
            }
            .sheet(item: $editingAnnotation) { annotation in
                CommentEditorView(
                    commentText: $editCommentText,
                    onSave: { text in
                        undoHistory.recordCommentEdit(
                            annotationID: annotation.id,
                            previousText: annotation.commentText,
                            newText: text
                        )
                        _ = documentManager.updateAnnotationText(
                            annotation: annotation,
                            newText: text
                        )
                        editingAnnotation = nil
                        onRefreshAnnotations()
                    },
                    onCancel: {
                        editingAnnotation = nil
                    }
                )
                .frame(width: 400, height: 250)
            }
            .sheet(isPresented: $showIssueCommentEditor) {
                CommentEditorView(
                    commentText: $issueEditorCommentText,
                    onSave: { text in
                        if let issue = issueEditorIssue {
                            let annotation = documentManager.createAnnotationForIssue(
                                comment: text,
                                source: .languageTool,
                                pageIndex: issue.pageIndex,
                                selectionText: issue.selectionText
                            )
                            undoHistory.recordIssueResolved(issueID: issue.id)
                            issueManager.resolveIssue(issue, annotationUUID: annotation?.id)
                            onRefreshIssues()
                            onRefreshAnnotations()
                            onAdvanceToNextUnresolved()
                        }
                        showIssueCommentEditor = false
                        issueEditorIssue = nil
                    },
                    onCancel: {
                        showIssueCommentEditor = false
                        issueEditorIssue = nil
                    }
                )
                .frame(width: 400, height: 250)
            }
    }
}

// MARK: - Debug Frame Overlay

private struct DebugOverlayModifier: ViewModifier {
    let label: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.overlay(alignment: .bottomTrailing) {
                GeometryReader { geo in
                    Text("\(label): \(Int(geo.size.width))×\(Int(geo.size.height))")
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(4)
                }
            }
            .overlay {
                GeometryReader { _ in
                    Rectangle()
                        .strokeBorder(debugColor, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
        } else {
            content
        }
    }

    private var debugColor: Color {
        switch label {
        case "Issues": return .orange
        case "PDF": return .blue
        case "Comments": return .green
        default: return .red
        }
    }
}

extension View {
    func debugOverlay(_ label: String, enabled: Bool) -> some View {
        modifier(DebugOverlayModifier(label: label, enabled: enabled))
    }
}
