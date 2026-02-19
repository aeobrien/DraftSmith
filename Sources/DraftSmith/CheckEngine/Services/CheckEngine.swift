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

        print("[CHECK] Starting document check — \(document.pageCount) pages, URL: \(documentURL ?? "nil")")

        // If LanguageTool isn't ready, try to start it first
        let initialLTState = serviceManager.serviceState(for: .languageTool)
        if !initialLTState.isReady {
            print("[CHECK] LanguageTool not ready (\(initialLTState)), attempting to start...")
            await serviceManager.ensureReady(.languageTool)
            let afterState = serviceManager.serviceState(for: .languageTool)
            print("[CHECK] LanguageTool state after ensureReady: \(afterState)")
        }

        var allIssues: [Issue] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                print("[CHECK] Page \(i): could not get PDFPage object")
                continue
            }
            guard let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                let rawString = page.string
                print("[CHECK] Page \(i): no extractable text (string is \(rawString == nil ? "nil" : "empty/whitespace"), \(page.annotations.count) annotations)")
                continue
            }

            print("[CHECK] Page \(i): extracted \(text.count) chars")

            let ltState = serviceManager.serviceState(for: .languageTool)
            if ltState.isReady {
                do {
                    let pageIssues = try await performLanguageToolCheck(
                        text: text,
                        pageIndex: i,
                        documentURL: documentURL
                    )
                    print("[CHECK] Page \(i): LanguageTool found \(pageIssues.count) issues")
                    allIssues.append(contentsOf: pageIssues)
                } catch {
                    print("[CHECK] Page \(i): LanguageTool check failed — \(error)")
                    let fastIssues = checkWithFastPath(text: text, pageIndex: i, documentURL: documentURL)
                    allIssues.append(contentsOf: fastIssues)
                }
            } else {
                print("[CHECK] Page \(i): LanguageTool not ready, using fast path")
                let fastIssues = checkWithFastPath(text: text, pageIndex: i, documentURL: documentURL)
                allIssues.append(contentsOf: fastIssues)
            }
        }

        print("[CHECK] Document check complete — \(allIssues.count) total issues found")
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
