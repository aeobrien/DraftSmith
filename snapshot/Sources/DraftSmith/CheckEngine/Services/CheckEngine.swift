import Foundation
import PDFKit

@Observable
@MainActor
final class CheckEngine: CheckEngineProtocol {
    private let serviceManager: ServiceManager
    private let issueManager: IssueManager
    private let profileManager: ProjectProfileManager

    private(set) var isChecking = false
    private var queuedChecks: [(text: String, pageIndex: Int, documentURL: String?)] = []

    init(
        serviceManager: ServiceManager,
        issueManager: IssueManager,
        profileManager: ProjectProfileManager
    ) {
        self.serviceManager = serviceManager
        self.issueManager = issueManager
        self.profileManager = profileManager
    }

    func checkSelection(text: String, pageIndex: Int, documentURL: String?) async throws -> [Issue] {
        isChecking = true
        defer { isChecking = false }

        let ltState = serviceManager.serviceState(for: .languageTool)

        if !ltState.isReady {
            // Queue for later and use fast path
            queuedChecks.append((text, pageIndex, documentURL))
            let fastPathIssues = checkWithFastPath(text: text, pageIndex: pageIndex, documentURL: documentURL)

            // Schedule deferred check
            Task {
                await serviceManager.ensureReady(.languageTool)
                await processQueuedChecks()
            }

            return fastPathIssues
        }

        return try await performLanguageToolCheck(text: text, pageIndex: pageIndex, documentURL: documentURL)
    }

    func checkDocument(document: PDFDocument, documentURL: String?) async throws -> [Issue] {
        isChecking = true
        defer { isChecking = false }

        // Clear ALL existing issues to prevent duplicates on re-check
        issueManager.clearAllIssues(for: documentURL)

        // If LanguageTool isn't ready, try to start it first
        let initialLTState = serviceManager.serviceState(for: .languageTool)
        if !initialLTState.isReady {
            await serviceManager.ensureReady(.languageTool)
        }

        var allIssues: [Issue] = []

        // --- Fix 1: Detect repeating headers/footers across all pages ---
        let repeatingHeaders = detectRepeatingHeaders(document: document)

        // --- Phase 1: Extract and normalize all pages ---
        struct PageText {
            let pageIndex: Int
            let normalized: String
        }
        var pageTexts: [PageText] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                continue
            }
            guard var rawText = page.string, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            // Strip detected repeating headers/footers
            if !repeatingHeaders.isEmpty {
                var lines = rawText.components(separatedBy: "\n")
                lines = lines.filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return !repeatingHeaders.contains(trimmed)
                }
                rawText = lines.joined(separator: "\n")
            }

            let text = PDFTextNormalizer.normalize(rawText)
            pageTexts.append(PageText(pageIndex: i, normalized: text))
        }

        // --- Fix 2: Merge pages where text ends mid-sentence ---
        // Track character offset ranges so we can map LanguageTool offsets back to the correct page.
        struct PageSegment {
            let pageIndex: Int
            let startOffset: Int  // character offset in the merged chunk text
            let endOffset: Int    // exclusive end offset
        }
        struct CheckChunk {
            let pageIndices: [Int]
            let segments: [PageSegment]  // maps character ranges to pages
            let text: String
        }
        var chunks: [CheckChunk] = []
        var pendingText = ""
        var pendingPages: [Int] = []
        var pendingSegments: [PageSegment] = []

        for pt in pageTexts {
            let startOffset = pendingText.isEmpty ? 0 : pendingText.count + 1  // +1 for the joining space
            if pendingPages.isEmpty {
                pendingText = pt.normalized
            } else {
                pendingText += " " + pt.normalized
            }
            let endOffset = pendingText.count
            pendingPages.append(pt.pageIndex)
            pendingSegments.append(PageSegment(pageIndex: pt.pageIndex, startOffset: startOffset, endOffset: endOffset))

            // Check if this page's text ends with terminal punctuation
            let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastChar = trimmed.last
            let isTerminal = lastChar == "." || lastChar == "!" || lastChar == "?" || lastChar == ":"
            if isTerminal || pt.pageIndex == pageTexts.last?.pageIndex {
                chunks.append(CheckChunk(pageIndices: pendingPages, segments: pendingSegments, text: pendingText))
                pendingText = ""
                pendingPages = []
                pendingSegments = []
            }
        }


        // --- Phase 2: Send merged chunks for checking ---
        // Helper: given a character offset in chunk text, find the correct page index
        func pageForOffset(_ offset: Int, segments: [PageSegment], fallback: Int) -> Int {
            for seg in segments {
                if offset >= seg.startOffset && offset < seg.endOffset {
                    return seg.pageIndex
                }
            }
            return fallback
        }

        for chunk in chunks {
            let primaryPage = chunk.pageIndices.first ?? 0

            let ltState = serviceManager.serviceState(for: .languageTool)
            if ltState.isReady {
                do {
                    // Get raw LanguageTool response so we can remap page indices
                    let config = profileManager.languageToolCheckConfig()
                    let response = try await serviceManager.languageToolService.check(
                        text: chunk.text,
                        enabledRules: config.enabledRules,
                        disabledRules: config.disabledRules,
                        enabledCategories: config.enabledCategories,
                        disabledCategories: config.disabledCategories,
                        level: config.level
                    )

                    let profile = profileManager.activeProfile
                    let converter = LanguageToolMatchConverter(
                        customDictionary: profile?.customDictionary ?? [],
                        terminologyPreferences: profile?.terminology ?? [],
                        severityOverrides: parseSeverityOverrides(profile?.severityOverrides ?? [:])
                    )

                    // Convert each match, remapping page index and offset based on character position
                    let chunkIssues = response.matches.compactMap { match -> Issue? in
                        let correctPage = pageForOffset(match.offset, segments: chunk.segments, fallback: primaryPage)
                        // Calculate page-relative offset by subtracting the segment's start offset
                        let pageRelativeOffset: Int? = chunk.segments
                            .first(where: { match.offset >= $0.startOffset && match.offset < $0.endOffset })
                            .map { match.offset - $0.startOffset }
                        return converter.convert(
                            match: match,
                            selectionText: chunk.text,
                            pageIndex: correctPage,
                            documentURL: documentURL,
                            textOffset: pageRelativeOffset
                        )
                    }

                    // Deduplicate (same logic as LanguageToolMatchConverter.convertAll)
                    var seen = Set<String>()
                    let dedupedIssues = chunkIssues.filter { issue in
                        let key = "\(issue.pageIndex)_\(issue.selectionText)"
                        return seen.insert(key).inserted
                    }

                    // Save to database so UI can fetch them
                    for issue in dedupedIssues {
                        issueManager.addIssue(issue)
                    }

                    allIssues.append(contentsOf: dedupedIssues)
                } catch {
                    let fastIssues = checkWithFastPath(text: chunk.text, pageIndex: primaryPage, documentURL: documentURL)
                    allIssues.append(contentsOf: fastIssues)
                }
            } else {
                let fastIssues = checkWithFastPath(text: chunk.text, pageIndex: primaryPage, documentURL: documentURL)
                allIssues.append(contentsOf: fastIssues)
            }
        }

        return allIssues
    }

    func checkWithFastPath(text: String, pageIndex: Int, documentURL: String?) -> [Issue] {
        let fastPathIssues = serviceManager.fastPathService.checkSpelling(text: text)
        return fastPathIssues.map { fpIssue in
            Issue(
                pageIndex: pageIndex,
                selectionText: fpIssue.word,
                message: "Possible spelling error: \(fpIssue.word)",
                suggestions: fpIssue.suggestions,
                source: .languageTool,
                severity: .warning,
                documentURL: documentURL
            )
        }
    }

    // MARK: - Private

    /// Detect strings that repeat as the first or last line on >30% of pages.
    /// These are running headers or footers that should be stripped.
    private func detectRepeatingHeaders(document: PDFDocument) -> Set<String> {
        guard document.pageCount > 2 else { return [] }

        var firstLineCounts: [String: Int] = [:]
        var lastLineCounts: [String: Int] = [:]
        var pagesWithText = 0

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i),
                  let rawText = page.string,
                  !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            pagesWithText += 1

            let lines = rawText.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if let first = lines.first {
                firstLineCounts[first, default: 0] += 1
            }
            if let last = lines.last {
                lastLineCounts[last, default: 0] += 1
            }
        }

        guard pagesWithText > 0 else { return [] }
        let threshold = Double(pagesWithText) * 0.3

        var repeating = Set<String>()
        for (line, count) in firstLineCounts where Double(count) > threshold {
            repeating.insert(line)
        }
        for (line, count) in lastLineCounts where Double(count) > threshold {
            repeating.insert(line)
        }

        return repeating
    }

    private func performLanguageToolCheck(text: String, pageIndex: Int, documentURL: String?) async throws -> [Issue] {
        let config = profileManager.languageToolCheckConfig()

        let response = try await serviceManager.languageToolService.check(
            text: text,
            enabledRules: config.enabledRules,
            disabledRules: config.disabledRules,
            enabledCategories: config.enabledCategories,
            disabledCategories: config.disabledCategories,
            level: config.level
        )

        let profile = profileManager.activeProfile
        let converter = LanguageToolMatchConverter(
            customDictionary: profile?.customDictionary ?? [],
            terminologyPreferences: profile?.terminology ?? [],
            severityOverrides: parseSeverityOverrides(profile?.severityOverrides ?? [:])
        )

        let issues = converter.convertAll(
            response: response,
            selectionText: text,
            pageIndex: pageIndex,
            documentURL: documentURL
        )

        // Skip issues that already exist in the database (prevents duplicates
        // when checkSelection is called multiple times on the same text)
        let existingIssues = issueManager.fetchIssues(for: documentURL)
        let existingKeys = Set(existingIssues.map { "\($0.pageIndex)_\($0.selectionText)_\($0.ruleID ?? "")" })

        var added: [Issue] = []
        for issue in issues {
            let key = "\(issue.pageIndex)_\(issue.selectionText)_\(issue.ruleID ?? "")"
            if !existingKeys.contains(key) {
                issueManager.addIssue(issue)
                added.append(issue)
            }
        }

        return added
    }

    private func processQueuedChecks() async {
        let checks = queuedChecks
        queuedChecks = []

        for check in checks {
            _ = try? await performLanguageToolCheck(
                text: check.text,
                pageIndex: check.pageIndex,
                documentURL: check.documentURL
            )
        }
    }

    private func parseSeverityOverrides(_ overrides: [String: String]) -> [String: IssueSeverity] {
        overrides.compactMapValues { IssueSeverity(rawValue: $0) }
    }
}
