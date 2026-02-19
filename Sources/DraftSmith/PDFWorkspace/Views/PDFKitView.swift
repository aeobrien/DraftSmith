import SwiftUI
import PDFKit
import AppKit

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    let onSelectionChanged: ((PDFSelection?) -> Void)?
    let onPageChanged: ((Int) -> Void)?

    @Binding var goToPageIndex: Int?
    @Binding var highlightText: String?
    @Binding var outlineBounds: CGRect?
    @Binding var outlinePageIndex: Int?
    @Binding var selectedAnnotationID: UUID?
    @Binding var issueUnderlines: [IssueLocation]

    /// Issue overlay info to display near the outline annotation.
    var issueOverlayInfo: IssueOverlayInfo?
    var showIssueOverlay: Bool

    /// Called when an issue underline annotation is clicked. Parameters: issueID, the PDFView (for popover positioning), view-relative rect.
    var onIssueAnnotationClicked: ((UUID, NSView, CGRect) -> Void)?
    /// Called when a comment highlight annotation is clicked. Parameter: annotation UUID.
    var onCommentAnnotationClicked: ((UUID) -> Void)?

    init(
        document: PDFDocument?,
        goToPageIndex: Binding<Int?> = .constant(nil),
        highlightText: Binding<String?> = .constant(nil),
        outlineBounds: Binding<CGRect?> = .constant(nil),
        outlinePageIndex: Binding<Int?> = .constant(nil),
        selectedAnnotationID: Binding<UUID?> = .constant(nil),
        issueUnderlines: Binding<[IssueLocation]> = .constant([]),
        issueOverlayInfo: IssueOverlayInfo? = nil,
        showIssueOverlay: Bool = false,
        onSelectionChanged: ((PDFSelection?) -> Void)? = nil,
        onPageChanged: ((Int) -> Void)? = nil,
        onIssueAnnotationClicked: ((UUID, NSView, CGRect) -> Void)? = nil,
        onCommentAnnotationClicked: ((UUID) -> Void)? = nil
    ) {
        self.document = document
        self._goToPageIndex = goToPageIndex
        self._highlightText = highlightText
        self._outlineBounds = outlineBounds
        self._outlinePageIndex = outlinePageIndex
        self._selectedAnnotationID = selectedAnnotationID
        self._issueUnderlines = issueUnderlines
        self.issueOverlayInfo = issueOverlayInfo
        self.showIssueOverlay = showIssueOverlay
        self.onSelectionChanged = onSelectionChanged
        self.onPageChanged = onPageChanged
        self.onIssueAnnotationClicked = onIssueAnnotationClicked
        self.onCommentAnnotationClicked = onCommentAnnotationClicked
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.document = document
        context.coordinator.pdfView = pdfView
        context.coordinator.setupNotifications()
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        // Navigate to page (only if no outline bounds — outline handling does its own scrolling)
        if let pageIndex = goToPageIndex, let page = document?.page(at: pageIndex) {
            if outlineBounds == nil {
                pdfView.go(to: page)
            }
            DispatchQueue.main.async {
                self.goToPageIndex = nil
            }
        }
        // Set text selection highlight (visual only, no scrolling)
        if let text = highlightText, !text.isEmpty, let document = document {
            let targetPageIndex = goToPageIndex ?? outlinePageIndex ?? (pdfView.currentPage.flatMap { document.index(for: $0) })
            DispatchQueue.main.async {
                // Search ALL matches, find the one on the target page
                if let pageIndex = targetPageIndex {
                    let allMatches = document.findString(text, withOptions: .caseInsensitive)
                    if let match = allMatches.first(where: { sel in
                        guard let p = sel.pages.first else { return false }
                        return document.index(for: p) == pageIndex
                    }) {
                        pdfView.setCurrentSelection(match, animate: true)
                    }
                }
                self.highlightText = nil
            }
        }

        // Update issue outline annotation and scroll to it
        let coordinator = context.coordinator
        let outlineChanged = coordinator.currentOutlineBounds != outlineBounds || coordinator.currentOutlinePageIndex != outlinePageIndex
        if outlineChanged {
            // Remove previous outline
            if let prev = coordinator.currentOutlineAnnotation, let page = coordinator.outlinePage {
                page.removeAnnotation(prev)
            }
            coordinator.currentOutlineAnnotation = nil
            coordinator.outlinePage = nil
            coordinator.currentOutlineBounds = outlineBounds
            coordinator.currentOutlinePageIndex = outlinePageIndex

            // Add new outline if bounds provided
            if let bounds = outlineBounds, let pageIdx = outlinePageIndex, let page = document?.page(at: pageIdx) {
                let inflated = bounds.insetBy(dx: -4, dy: -4)
                let outline = PDFAnnotation(bounds: inflated, forType: .square, withProperties: nil)
                outline.color = .red
                outline.border = PDFBorder()
                outline.border?.lineWidth = 2
                outline.interiorColor = nil
                let outlineTagKey = PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueOutlineKey)
                outline.setValue("true", forAnnotationKey: outlineTagKey)
                page.addAnnotation(outline)
                coordinator.currentOutlineAnnotation = outline
                coordinator.outlinePage = page

                // Scroll to center the outline in the viewport
                Self.scrollToCenterBounds(pdfView: pdfView, bounds: bounds, page: page)
            }
        }

        // Update issue overlay
        coordinator.updateIssueOverlay(
            pdfView: pdfView,
            info: showIssueOverlay ? issueOverlayInfo : nil,
            outlineBounds: outlineBounds,
            outlinePageIndex: outlinePageIndex,
            document: document
        )

        // Update selected annotation highlight
        let dsUUIDKey = PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)
        if coordinator.currentSelectedAnnotationID != selectedAnnotationID {
            // Restore previous annotation color
            if let prev = coordinator.previouslySelectedAnnotation {
                prev.color = .yellow
            }
            coordinator.previouslySelectedAnnotation = nil
            coordinator.currentSelectedAnnotationID = selectedAnnotationID

            // Find and highlight new annotation
            if let targetID = selectedAnnotationID, let document = document {
                let targetString = targetID.uuidString
                outer: for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    for annotation in page.annotations {
                        if let storedUUID = annotation.value(forAnnotationKey: dsUUIDKey) as? String,
                           storedUUID == targetString {
                            annotation.color = .orange
                            coordinator.previouslySelectedAnnotation = annotation
                            break outer
                        }
                    }
                }
            }
        }

        // Update issue underline annotations
        coordinator.onIssueAnnotationClicked = onIssueAnnotationClicked
        coordinator.onCommentAnnotationClicked = onCommentAnnotationClicked
        coordinator.updateUnderlines(issueUnderlines, document: document)
    }

    /// Scrolls the PDFView so that the given bounds (in page coordinates) are vertically centred.
    /// Uses PDFDestination to position a point at the top of the visible area, offset so
    /// the selection ends up in the middle of the viewport.
    private static func scrollToCenterBounds(pdfView: PDFView, bounds: CGRect, page: PDFPage) {
        let scaleFactor = pdfView.scaleFactor
        guard scaleFactor > 0 else {
            pdfView.go(to: bounds, on: page)
            return
        }

        // Get the actual viewport height from the internal scroll view's clip view
        let viewportHeightInPoints: CGFloat
        if let scrollView = pdfView.subviews.compactMap({ $0 as? NSScrollView }).first {
            viewportHeightInPoints = scrollView.contentView.bounds.height
        } else if let scrollView = pdfView.enclosingScrollView {
            viewportHeightInPoints = scrollView.contentView.bounds.height
        } else {
            // Fallback: use PDFView frame
            viewportHeightInPoints = pdfView.frame.height
        }

        // Convert viewport height to page coordinate units
        let viewportHeightInPageCoords = viewportHeightInPoints / scaleFactor

        // PDFDestination(page:at:) scrolls so the given point is at the TOP of the visible area.
        // To center selMidY, we want the top of the viewport to be at selMidY + halfViewport.
        // In PDF page coordinates, Y increases upward, so "above" means higher Y.
        let destY = bounds.midY + viewportHeightInPageCoords / 2.0
        let destination = PDFDestination(page: page, at: NSPoint(x: 0, y: destY))
        pdfView.go(to: destination)

        print("[SCROLL-DEBUG] scrollToCenterBounds: page=\(pdfView.document?.index(for: page) ?? -1) bounds=\(bounds) scaleFactor=\(scaleFactor) viewportPx=\(viewportHeightInPoints) viewportPage=\(viewportHeightInPageCoords) destY=\(destY)")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged, onPageChanged: onPageChanged)
    }

    class Coordinator: NSObject {
        weak var pdfView: PDFView?
        let onSelectionChanged: ((PDFSelection?) -> Void)?
        let onPageChanged: ((Int) -> Void)?

        // Issue outline tracking
        weak var currentOutlineAnnotation: PDFAnnotation?
        weak var outlinePage: PDFPage?
        var currentOutlineBounds: CGRect?
        var currentOutlinePageIndex: Int?

        // Selected comment highlight tracking
        weak var previouslySelectedAnnotation: PDFAnnotation?
        var currentSelectedAnnotationID: UUID?

        // Issue underline tracking
        var currentUnderlineAnnotations: [UUID: PDFAnnotation] = [:]
        var underlinePages: [UUID: PDFPage] = [:]
        var onIssueAnnotationClicked: ((UUID, NSView, CGRect) -> Void)?
        var onCommentAnnotationClicked: ((UUID) -> Void)?

        // Issue overlay
        var overlayHostingView: NSView?

        init(
            onSelectionChanged: ((PDFSelection?) -> Void)?,
            onPageChanged: ((Int) -> Void)?
        ) {
            self.onSelectionChanged = onSelectionChanged
            self.onPageChanged = onPageChanged
        }

        func setupNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(selectionChanged),
                name: .PDFViewSelectionChanged,
                object: pdfView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChanged),
                name: .PDFViewPageChanged,
                object: pdfView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(annotationHit(_:)),
                name: .PDFViewAnnotationHit,
                object: pdfView
            )
        }

        @objc private func selectionChanged(_ notification: Notification) {
            let selection = pdfView?.currentSelection
            onSelectionChanged?(selection)
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            onPageChanged?(index)
        }

        @objc private func annotationHit(_ notification: Notification) {
            guard let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation else { return }

            // Check if it's an issue underline annotation
            let tagKey = PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueUnderlineKey)
            if let tag = annotation.value(forAnnotationKey: tagKey) as? String, tag == "true" {
                guard let issueID = currentUnderlineAnnotations.first(where: { $0.value === annotation })?.key else { return }
                guard let pdfView = pdfView, let page = annotation.page else { return }
                let pageBounds = annotation.bounds
                let viewRect = pdfView.convert(pageBounds, from: page)
                onIssueAnnotationClicked?(issueID, pdfView, viewRect)
                return
            }

            // Check if it's a comment highlight annotation (has dsUUID)
            let dsUUIDKey = PDFAnnotationKey(rawValue: AppConstants.dsUUIDAnnotationKey)
            if let uuidString = annotation.value(forAnnotationKey: dsUUIDKey) as? String,
               let uuid = UUID(uuidString: uuidString) {
                onCommentAnnotationClicked?(uuid)
            }
        }

        func updateIssueOverlay(
            pdfView: PDFView,
            info: IssueOverlayInfo?,
            outlineBounds: CGRect?,
            outlinePageIndex: Int?,
            document: PDFDocument?
        ) {
            // Remove existing overlay if info is nil or bounds are missing
            guard let info = info,
                  let bounds = outlineBounds,
                  let pageIdx = outlinePageIndex,
                  let page = document?.page(at: pageIdx) else {
                overlayHostingView?.removeFromSuperview()
                overlayHostingView = nil
                return
            }

            // Convert outline bounds from page coordinates to PDFView coordinates
            let viewRect = pdfView.convert(bounds, from: page)

            // Build the overlay content
            let overlayContent = IssueOverlayView(info: info)
            let hostingView: NSHostingView<IssueOverlayView>

            if let existing = overlayHostingView as? NSHostingView<IssueOverlayView> {
                existing.rootView = overlayContent
                hostingView = existing
            } else {
                overlayHostingView?.removeFromSuperview()
                hostingView = NSHostingView(rootView: overlayContent)
                hostingView.wantsLayer = true
                overlayHostingView = hostingView
                // Add as subview of the PDFView itself (not documentView) so it stays
                // in view coordinates and renders at native resolution
                pdfView.addSubview(hostingView)
            }

            // Ensure crisp rendering at Retina scale
            if let window = pdfView.window {
                hostingView.layer?.contentsScale = window.backingScaleFactor
            }

            let fittingSize = hostingView.fittingSize
            let overlayWidth = fittingSize.width
            let overlayHeight = fittingSize.height

            // viewRect is in pdfView coordinates (flipped: origin top-left)
            // Place below the outline; if not enough room, place above
            let gap: CGFloat = 6
            var originY: CGFloat
            if pdfView.isFlipped {
                // Flipped: Y increases downward
                originY = viewRect.maxY + gap
                if originY + overlayHeight > pdfView.bounds.height {
                    originY = viewRect.minY - overlayHeight - gap
                }
            } else {
                // Non-flipped: Y increases upward, "below" = lower Y
                originY = viewRect.minY - overlayHeight - gap
                if originY < 0 {
                    originY = viewRect.maxY + gap
                }
            }

            let originX = max(4, min(viewRect.midX - overlayWidth / 2, pdfView.bounds.width - overlayWidth - 4))
            hostingView.frame = CGRect(x: originX, y: originY, width: overlayWidth, height: overlayHeight)
        }

        func updateUnderlines(_ locations: [IssueLocation], document: PDFDocument?) {
            guard let document = document else {
                removeAllUnderlines()
                return
            }

            let newIDs = Set(locations.map(\.issueID))
            let existingIDs = Set(currentUnderlineAnnotations.keys)

            // Remove stale underlines
            for id in existingIDs.subtracting(newIDs) {
                if let annotation = currentUnderlineAnnotations[id],
                   let page = underlinePages[id] {
                    page.removeAnnotation(annotation)
                }
                currentUnderlineAnnotations.removeValue(forKey: id)
                underlinePages.removeValue(forKey: id)
            }

            // Add new underlines — thin 2pt line at the bottom of text bounds
            for location in locations where !existingIDs.contains(location.issueID) {
                guard let page = document.page(at: location.pageIndex) else { continue }
                let underlineBounds = CGRect(
                    x: location.bounds.origin.x,
                    y: location.bounds.origin.y,
                    width: location.bounds.width,
                    height: 2
                )
                let annotation = PDFAnnotation(bounds: underlineBounds, forType: .highlight, withProperties: nil)
                annotation.color = NSColor.red.withAlphaComponent(0.5)
                let tagKey = PDFAnnotationKey(rawValue: PDFDocumentManager.dsIssueUnderlineKey)
                annotation.setValue("true", forAnnotationKey: tagKey)
                page.addAnnotation(annotation)
                currentUnderlineAnnotations[location.issueID] = annotation
                underlinePages[location.issueID] = page
            }
        }

        func removeAllUnderlines() {
            for (id, annotation) in currentUnderlineAnnotations {
                if let page = underlinePages[id] {
                    page.removeAnnotation(annotation)
                }
            }
            currentUnderlineAnnotations.removeAll()
            underlinePages.removeAll()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Issue Overlay View

struct IssueOverlayView: View {
    let info: IssueOverlayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let category = info.category {
                Text(category.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.red)
            }
            Text(info.message)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let suggestion = info.suggestion, !suggestion.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                    Text(suggestion)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 320, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
        }
    }
}
