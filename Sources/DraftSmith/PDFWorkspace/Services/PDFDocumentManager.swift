import Foundation
import PDFKit
import SwiftUI
import AppKit

struct DocumentManagerKey: FocusedValueKey {
    typealias Value = PDFDocumentManager
}

extension FocusedValues {
    var documentManager: PDFDocumentManager? {
        get { self[DocumentManagerKey.self] }
        set { self[DocumentManagerKey.self] = newValue }
    }
}

extension Notification.Name {
    static let saveAsRequested = Notification.Name("DraftSmith.saveAsRequested")
    static let openRecentRequested = Notification.Name("DraftSmith.openRecentRequested")
    static let openPDFRequested = Notification.Name("DraftSmith.openPDFRequested")
}

struct IssueLocation: Equatable {
    let issueID: UUID
    let pageIndex: Int
    let bounds: CGRect
}

@Observable
@MainActor
final class PDFDocumentManager {
    private(set) var document: PDFDocument?
    private(set) var documentURL: URL?
    private(set) var currentPageIndex: Int = 0
    private(set) var currentSelection: PDFSelection?
    private(set) var isModified: Bool = false
    var pendingNavigation: Int?
    var pendingHighlightText: String?
    var issueOutlineBounds: CGRect?
    var issueOutlinePageIndex: Int?
    var selectedAnnotationID: UUID?

    // MARK: - Inline Issue Markers
    var showInlineMarkers: Bool = false
    var issueUnderlineLocations: [IssueLocation] = []

    /// Tag key used to identify DraftSmith issue underline annotations
    nonisolated static let dsIssueUnderlineKey = "ds_issue_underline"
    /// Tag key used to identify the DraftSmith issue outline (red box) annotation
    nonisolated static let dsIssueOutlineKey = "ds_issue_outline"

    let annotationService: PDFAnnotationService
    nonisolated(unsafe) private var autosaveTimer: Timer?
    nonisolated(unsafe) private var deactivationObserver: NSObjectProtocol?

    init(annotationService: PDFAnnotationService) {
        self.annotationService = annotationService
        setupDeactivationObserver()
    }

    convenience init() {
        self.init(annotationService: PDFAnnotationService())
    }

    deinit {
        autosaveTimer?.invalidate()
        if let observer = deactivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupDeactivationObserver() {
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.autosaveIfNeeded()
            }
        }
    }

    private func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.autosaveIfNeeded()
            }
        }
    }

    private func autosaveIfNeeded() {
        guard isModified, documentURL != nil else { return }
        try? save()
    }

    func open(url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let doc = PDFDocument(url: url) else {
            throw DraftSmithError.pdfOpenFailed(url)
        }
        autosaveTimer?.invalidate()
        self.document = doc
        self.documentURL = url
        self.currentPageIndex = 0
        self.currentSelection = nil
        self.isModified = false
        // Debug: dump all annotations on every page BEFORE stripping
        print("[HIGHLIGHT-DEBUG] === Document opened: \(url.lastPathComponent) ===")
        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            let anns = page.annotations
            if !anns.isEmpty {
                print("[HIGHLIGHT-DEBUG] Page \(pageIndex): \(anns.count) annotations")
                for (i, ann) in anns.enumerated() {
                    let type = ann.type ?? "nil"
                    let color = ann.color
                    let bounds = ann.bounds
                    // Check all known DraftSmith keys
                    let underlineTag = ann.value(forAnnotationKey: PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueUnderlineKey))
                    let outlineTag = ann.value(forAnnotationKey: PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueOutlineKey))
                    let dsUUID = ann.value(forAnnotationKey: PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey))
                    print("[HIGHLIGHT-DEBUG]   [\(i)] type=\(type) color=\(color) bounds=\(bounds) underlineTag=\(underlineTag ?? "nil") outlineTag=\(outlineTag ?? "nil") dsUUID=\(dsUUID ?? "nil")")
                }
            }
        }
        // Remove any DraftSmith annotations that were baked into the saved PDF
        stripStaleDraftSmithAnnotations()
        // Debug: dump annotations AFTER stripping
        print("[HIGHLIGHT-DEBUG] === After stripping stale annotations ===")
        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            let anns = page.annotations
            if !anns.isEmpty {
                print("[HIGHLIGHT-DEBUG] Page \(pageIndex): \(anns.count) annotations remaining")
                for (i, ann) in anns.enumerated() {
                    let type = ann.type ?? "nil"
                    let color = ann.color
                    print("[HIGHLIGHT-DEBUG]   [\(i)] type=\(type) color=\(color) bounds=\(ann.bounds)")
                }
            }
        }
    }

    func save() throws {
        guard let document = document, let url = documentURL else { return }
        let stripped = stripDraftSmithAnnotations()
        guard document.write(to: url) else {
            restoreDraftSmithAnnotations(stripped)
            throw DraftSmithError.pdfSaveFailed(url)
        }
        restoreDraftSmithAnnotations(stripped)
        isModified = false
        autosaveTimer?.invalidate()
    }

    func saveAs(url: URL) throws {
        guard let document = document else { return }
        let stripped = stripDraftSmithAnnotations()
        guard document.write(to: url) else {
            restoreDraftSmithAnnotations(stripped)
            throw DraftSmithError.pdfSaveFailed(url)
        }
        restoreDraftSmithAnnotations(stripped)
        documentURL = url
        isModified = false
        autosaveTimer?.invalidate()
    }

    func goToPage(_ index: Int) {
        guard let document = document,
              index >= 0, index < document.pageCount else { return }
        currentPageIndex = index
    }

    func navigateToIssue(pageIndex: Int, highlightText: String?) {
        guard let document = document,
              pageIndex >= 0, pageIndex < document.pageCount else { return }
        currentPageIndex = pageIndex
        pendingNavigation = pageIndex
        pendingHighlightText = highlightText
    }

    func nextPage() {
        goToPage(currentPageIndex + 1)
    }

    func previousPage() {
        goToPage(currentPageIndex - 1)
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    func setSelection(_ selection: PDFSelection?) {
        currentSelection = selection
    }

    func markModified() {
        isModified = true
        scheduleAutosave()
    }

    func createAnnotation(comment: String, source: AnnotationSource) -> DSAnnotation? {
        guard let document = document, let selection = currentSelection else { return nil }
        let annotation = annotationService.createHighlightWithComment(
            on: document,
            selection: selection,
            comment: comment,
            source: source
        )
        if annotation != nil {
            markModified()
        }
        return annotation
    }

    /// Creates an annotation at the location of an issue's flagged text, even without a current selection.
    func createAnnotationForIssue(comment: String, source: AnnotationSource, pageIndex: Int, selectionText: String) -> DSAnnotation? {
        guard let document = document else { return nil }
        // First try using the current selection if it's on the right page
        if let selection = currentSelection, currentPageIndex == pageIndex {
            let annotation = annotationService.createHighlightWithComment(
                on: document,
                selection: selection,
                comment: comment,
                source: source
            )
            if annotation != nil {
                markModified()
                return annotation
            }
        }
        // Otherwise, search for the flagged text on the issue's page
        if let page = document.page(at: pageIndex) {
            if let selection = document.findString(selectionText, withOptions: [])
                .first(where: { sel in sel.pages.contains(page) }) {
                let annotation = annotationService.createHighlightWithComment(
                    on: document,
                    selection: selection,
                    comment: comment,
                    source: source
                )
                if annotation != nil {
                    markModified()
                    return annotation
                }
            }
        }
        return nil
    }

    // MARK: - Background rewrite suggestions

    /// Maps annotation UUID → suggested rewrite text from background generation.
    var rewriteSuggestions: [UUID: String] = [:]

    func clearSuggestion(for annotationID: UUID) {
        rewriteSuggestions.removeValue(forKey: annotationID)
    }

    // MARK: - Original text tracking for rewrites

    /// Maps annotation UUID → original comment text before any rewrite.
    private(set) var originalCommentTexts: [UUID: String] = [:]

    func updateAnnotationText(annotation: DSAnnotation, newText: String) -> DSAnnotation? {
        guard let document = document else { return nil }
        // Store the original text before first rewrite
        if originalCommentTexts[annotation.id] == nil {
            originalCommentTexts[annotation.id] = annotation.commentText
        }
        let updated = annotationService.updateComment(
            on: document,
            annotation: annotation,
            newComment: newText
        )
        if updated != nil { markModified() }
        return updated
    }

    func revertAnnotation(annotation: DSAnnotation) -> DSAnnotation? {
        guard let document = document,
              let originalText = originalCommentTexts[annotation.id] else { return nil }
        let reverted = annotationService.updateComment(
            on: document,
            annotation: annotation,
            newComment: originalText
        )
        if reverted != nil {
            originalCommentTexts.removeValue(forKey: annotation.id)
            markModified()
        }
        return reverted
    }

    func hasOriginalText(for annotationID: UUID) -> Bool {
        originalCommentTexts[annotationID] != nil
    }

    func allAnnotations() -> [DSAnnotation] {
        guard let document = document else { return [] }
        var annotations = annotationService.readAnnotations(from: document)
        // Restore originalCommentText field for annotations that have been rewritten
        for i in annotations.indices {
            if let original = originalCommentTexts[annotations[i].id] {
                annotations[i].originalCommentText = original
            }
        }
        return annotations
    }

    // MARK: - Issue Location Resolution

    func resolveIssueLocations(for issues: [Issue]) -> [IssueLocation] {
        guard let document = document else { return [] }
        var locations: [IssueLocation] = []
        for issue in issues where issue.issueStatus == .new {
            guard let page = document.page(at: issue.pageIndex) else { continue }
            if let selection = document.findString(issue.selectionText, withOptions: [])
                .first(where: { sel in sel.pages.contains(page) }) {
                let bounds = selection.bounds(for: page)
                locations.append(IssueLocation(
                    issueID: issue.id,
                    pageIndex: issue.pageIndex,
                    bounds: bounds
                ))
            }
        }
        return locations
    }

    // MARK: - DraftSmith Annotation Management

    /// Strips all DraftSmith-managed annotations (issue underlines and outline boxes) from the document.
    /// Returns them so they can be restored after save.
    private func stripDraftSmithAnnotations() -> [(PDFPage, PDFAnnotation)] {
        guard let document = document else { return [] }
        var stripped: [(PDFPage, PDFAnnotation)] = []
        let underlineTagKey = PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueUnderlineKey)
        let outlineTagKey = PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueOutlineKey)
        let dsUUIDKey = PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                if let tag = annotation.value(forAnnotationKey: underlineTagKey) as? String, tag == "true" {
                    stripped.append((page, annotation))
                    page.removeAnnotation(annotation)
                } else if let tag = annotation.value(forAnnotationKey: outlineTagKey) as? String, tag == "true" {
                    stripped.append((page, annotation))
                    page.removeAnnotation(annotation)
                } else if annotation.type == "Square" {
                    // Also strip old untagged red Square annotations (from before tagging was added).
                    // Only strip if it has no dsUUID (i.e., it's not a user-created annotation).
                    let hasDsUUID = annotation.value(forAnnotationKey: dsUUIDKey) as? String != nil
                    if !hasDsUUID {
                        stripped.append((page, annotation))
                        page.removeAnnotation(annotation)
                    }
                }
            }
        }
        return stripped
    }

    private func restoreDraftSmithAnnotations(_ stripped: [(PDFPage, PDFAnnotation)]) {
        for (page, annotation) in stripped {
            page.addAnnotation(annotation)
        }
    }

    /// Removes any DraftSmith-managed annotations that were persisted into the PDF file.
    /// Called on document open to prevent stale highlights from appearing.
    func stripStaleDraftSmithAnnotations() {
        _ = stripDraftSmithAnnotations()
    }
}
