import XCTest
import PDFKit
@testable import DraftSmith

/// Integration test that exercises the full PDF pipeline (extract -> strip headers
/// -> normalize -> merge cross-page sentences) against real test PDFs.
///
/// Run with:  swift test --filter PDFPipelineIntegrationTests
final class PDFPipelineIntegrationTests: XCTestCase {

    // MARK: - Test PDF paths

    static let testDir = "/Users/aidan/Downloads/TestPDFs"
    static let testPDFPrefixes: [(prefix: String, label: String)] = [
        ("Neuroscience Of Mind Empowerment", "Neuroscience"),
        ("Entangled Life", "Entangled Life"),
        ("Ethics and Issues in Contemporary Nursing", "Ethics Nursing"),
        ("Guesstimation", "Guesstimation"),
        ("Sources of Power", "Sources of Power"),
        ("TheMindIlluminated", "Mind Illuminated"),
    ]

    static var testPDFs: [(path: String, label: String)] {
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: testDir)) ?? []
        return testPDFPrefixes.compactMap { (prefix, label) in
            guard let match = allFiles.first(where: { $0.hasPrefix(prefix) && $0.hasSuffix(".pdf") }) else {
                return nil
            }
            return (path: testDir + "/" + match, label: label)
        }
    }

    // MARK: - Helpers (mirror CheckEngine logic for testing without LanguageTool)

    /// Detect repeating first/last lines across pages (>30% threshold).
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

    /// Count orphaned punctuation instances in raw text before normalization.
    private func countOrphanedPunctuation(in text: String) -> Int {
        let pattern = #"\n[ \t]*[.,;:!?][ \t]*(?=\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.numberOfMatches(in: text, range: range)
    }

    struct PageText {
        let pageIndex: Int
        let normalized: String
    }

    struct CheckChunk {
        let pageIndices: [Int]
        let text: String
    }

    // MARK: - The test

    func testAllPDFs() throws {
        for (path, label) in Self.testPDFs {
            print("\n" + String(repeating: "=", count: 80))
            print("PDF: \(label)")

            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                print("  SKIPPED: file not found at path")
                continue
            }
            guard let document = PDFDocument(url: url) else {
                print("  SKIPPED: PDFDocument could not open file")
                continue
            }

            let pageCount = document.pageCount
            print("  Total pages: \(pageCount)")

            // Quick text check
            var pagesWithText = 0
            for i in 0..<min(10, pageCount) {
                if let page = document.page(at: i),
                   let text = page.string,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pagesWithText += 1
                }
            }
            if pagesWithText == 0 {
                print("  SKIPPED: No extractable text (scanned/image PDF)")
                continue
            }

            // --- Fix 1: Header detection ---
            let headers = detectRepeatingHeaders(document: document)
            print("  Headers/footers detected: \(headers.count)")
            for h in headers.sorted().prefix(5) {
                let display = h.count > 70 ? String(h.prefix(70)) + "..." : h
                print("    - \"\(display)\"")
            }

            // --- Process pages ---
            var orphanedCount = 0
            var headersStrippedLines = 0
            var pageTexts: [PageText] = []

            for i in 0..<pageCount {
                guard let page = document.page(at: i),
                      var rawText = page.string,
                      !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }

                orphanedCount += countOrphanedPunctuation(in: rawText)

                if !headers.isEmpty {
                    let lines = rawText.components(separatedBy: "\n")
                    let filtered = lines.filter { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        return !headers.contains(trimmed)
                    }
                    headersStrippedLines += (lines.count - filtered.count)
                    rawText = filtered.joined(separator: "\n")
                }

                let text = PDFTextNormalizer.normalize(rawText)
                pageTexts.append(PageText(pageIndex: i, normalized: text))
            }

            print("  Header/footer lines stripped: \(headersStrippedLines)")
            print("  Orphaned punctuation instances fixed: \(orphanedCount)")

            // --- Fix 2: Cross-page merging ---
            var chunks: [CheckChunk] = []
            var pendingText = ""
            var pendingPages: [Int] = []

            for pt in pageTexts {
                if pendingPages.isEmpty {
                    pendingText = pt.normalized
                    pendingPages = [pt.pageIndex]
                } else {
                    pendingText += " " + pt.normalized
                    pendingPages.append(pt.pageIndex)
                }

                let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastChar = trimmed.last
                let isTerminal = lastChar == "." || lastChar == "!" || lastChar == "?" || lastChar == ":"
                if isTerminal || pt.pageIndex == pageTexts.last?.pageIndex {
                    chunks.append(CheckChunk(pageIndices: pendingPages, text: pendingText))
                    pendingText = ""
                    pendingPages = []
                }
            }

            let mergedChunks = chunks.filter { $0.pageIndices.count > 1 }
            var mergedPageCount = 0
            for c in mergedChunks { mergedPageCount += c.pageIndices.count }

            print("  Pages merged (mid-sentence breaks): \(mergedPageCount)")
            print("  Final chunks for checking: \(chunks.count)")

            // --- Sample text from pages 5-6 ---
            print()
            print("  Sample text (pages 5-6 region, first 500 chars):")
            var sampleFound = false
            for chunk in chunks {
                if chunk.pageIndices.contains(4) || chunk.pageIndices.contains(5) {
                    let sample = String(chunk.text.prefix(500))
                    for line in sample.components(separatedBy: "\n") {
                        print("    \(line)")
                    }
                    sampleFound = true
                    break
                }
            }
            if !sampleFound {
                if let fallback = chunks.dropFirst(min(2, chunks.count)).first {
                    let sample = String(fallback.text.prefix(500))
                    for line in sample.components(separatedBy: "\n") {
                        print("    \(line)")
                    }
                } else {
                    print("    (no suitable pages found)")
                }
            }
        }

        print("\n" + String(repeating: "=", count: 80))
        print("Pipeline integration test complete.")
    }
}
