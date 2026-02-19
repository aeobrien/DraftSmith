import SwiftUI
import PDFKit

struct PDFWorkspaceView: View {
    @Environment(PDFDocumentManager.self) private var documentManager
    @State private var showCommentEditor = false
    @State private var newCommentText = ""
    @State private var goToPageIndex: Int?
    @State private var highlightText: String?
    @State private var outlineBounds: CGRect?
    @State private var outlinePageIndex: Int?
    @State private var selectedAnnotationID: UUID?
    @State private var issueUnderlines: [IssueLocation] = []
    @State private var issueOverlayInfo: IssueOverlayInfo?
    @State private var showIssueOverlay: Bool = true
    @State private var showFileImporter = false
    @State private var showUnsavedChangesAlert = false

    /// Called after a comment is created so the parent can refresh annotations.
    var onAnnotationsChanged: (() -> Void)?
    /// Called when an issue underline annotation is clicked, passing issue ID, the PDFView (for popover positioning), and view-relative rect.
    var onIssueAnnotationClicked: ((UUID, NSView, CGRect) -> Void)?
    /// Called when a comment highlight annotation is clicked in the PDF.
    var onCommentAnnotationClicked: ((UUID) -> Void)?

    var body: some View {
        Group {
            if documentManager.document != nil {
                PDFKitView(
                    document: documentManager.document,
                    goToPageIndex: $goToPageIndex,
                    highlightText: $highlightText,
                    outlineBounds: $outlineBounds,
                    outlinePageIndex: $outlinePageIndex,
                    selectedAnnotationID: $selectedAnnotationID,
                    issueUnderlines: $issueUnderlines,
                    issueOverlayInfo: issueOverlayInfo,
                    showIssueOverlay: showIssueOverlay,
                    onSelectionChanged: { selection in
                        documentManager.setSelection(selection)
                    },
                    onPageChanged: { index in
                        documentManager.goToPage(index)
                    },
                    onIssueAnnotationClicked: { issueID, view, rect in
                        onIssueAnnotationClicked?(issueID, view, rect)
                    },
                    onCommentAnnotationClicked: { uuid in
                        onCommentAnnotationClicked?(uuid)
                    }
                )
            } else {
                emptyStateView
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    requestOpenPDF()
                } label: {
                    Label("Open PDF", systemImage: "doc.badge.plus")
                }

                if documentManager.isModified {
                    Button {
                        try? documentManager.save()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                openDocument(url: url)
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save and Open") {
                try? documentManager.save()
                showFileImporter = true
            }
            Button("Discard and Open", role: .destructive) {
                showFileImporter = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes to the current document. Would you like to save before opening a new file?")
        }
        .sheet(isPresented: $showCommentEditor) {
            CommentEditorView(
                commentText: $newCommentText,
                onSave: { text in
                    _ = documentManager.createAnnotation(comment: text, source: .manual)
                    showCommentEditor = false
                    onAnnotationsChanged?()
                },
                onCancel: {
                    showCommentEditor = false
                }
            )
            .frame(width: 400, height: 250)
        }
        .onChange(of: documentManager.pendingNavigation) { _, newValue in
            if let pageIndex = newValue {
                goToPageIndex = pageIndex
                documentManager.pendingNavigation = nil
            }
        }
        .onChange(of: documentManager.pendingHighlightText) { _, newValue in
            if let text = newValue {
                highlightText = text
                documentManager.pendingHighlightText = nil
            }
        }
        .onChange(of: documentManager.issueOutlineBounds) { _, newValue in
            outlineBounds = newValue
        }
        .onChange(of: documentManager.issueOutlinePageIndex) { _, newValue in
            outlinePageIndex = newValue
        }
        .onChange(of: documentManager.selectedAnnotationID) { _, newValue in
            selectedAnnotationID = newValue
        }
        .onChange(of: documentManager.issueUnderlineLocations) { _, newValue in
            issueUnderlines = newValue
        }
        .onChange(of: documentManager.issueOverlayInfo) { _, newValue in
            issueOverlayInfo = newValue
        }
        .onChange(of: documentManager.showIssueOverlay) { _, newValue in
            showIssueOverlay = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPDFRequested)) { _ in
            requestOpenPDF()
        }
    }

    private func requestOpenPDF() {
        if documentManager.document != nil && documentManager.isModified {
            showUnsavedChangesAlert = true
        } else {
            showFileImporter = true
        }
    }

    private func openDocument(url: URL) {
        try? documentManager.open(url: url)
        RecentDocumentsManager.shared.addDocument(url: url)
        onAnnotationsChanged?()
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No PDF Open", systemImage: "doc.text")
        } description: {
            Text("Open a PDF file to start proofreading.")
        } actions: {
            Button("Open PDF...") {
                showFileImporter = true
            }
        }
    }

    // Called by parent to trigger comment editor
    func showAddComment() {
        newCommentText = ""
        showCommentEditor = true
    }
}
