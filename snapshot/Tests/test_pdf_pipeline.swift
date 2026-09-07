#!/usr/bin/env xcrun swift

// Standalone test script for the PDF checking pipeline fixes.
// Run: xcrun swift Tests/test_pdf_pipeline.swift
// OR:  swift Tests/test_pdf_pipeline.swift

import Foundation
import PDFKit

// ---------------------------------------------------------------------------
// Inline normalizer (mirrors Sources/DraftSmith/CheckEngine/Services/PDFTextNormalizer.swift)
// ---------------------------------------------------------------------------

struct PDFTextNormalizer {
    static func normalize(_ text: String) -> String {
        var result = text
        result = rejoinHyphenatedLineBreaks(result)
        result = normalizeDashes(result)
        result = normalizeLigatures(result)
        result = removeStandalonePageNumbers(result)
        result = mergeOrphanedPunctuation(result)
        result = rejoinWrappedLines(result)
        result = collapseBlankLineRuns(result)
        result = collapseExtraWhitespace(result)
        return result
    }

    static func rejoinHyphenatedLineBreaks(_ text: String) -> String {
        let pattern = #"(\w)-[ \t]*\r?\n[ \t]*([a-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1$2")
    }

    static func normalizeDashes(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00AD}", with: "")
    }

    static func normalizeLigatures(_ text: String) -> String {
        var r = text
        r = r.replacingOccurrences(of: "\u{FB00}", with: "ff")
        r = r.replacingOccurrences(of: "\u{FB01}", with: "fi")
        r = r.replacingOccurrences(of: "\u{FB02}", with: "fl")
        r = r.replacingOccurrences(of: "\u{FB03}", with: "ffi")
        r = r.replacingOccurrences(of: "\u{FB04}", with: "ffl")
        r = r.replacingOccurrences(of: "\u{FB05}", with: "st")
        r = r.replacingOccurrences(of: "\u{FB06}", with: "st")
        return r
    }

    static func removeStandalonePageNumbers(_ text: String) -> String {
        let pattern = #"(?m)^\s*\d{1,3}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    static func mergeOrphanedPunctuation(_ text: String) -> String {
        let pattern = #"\n[ \t]*([.,;:!?])[ \t]*(?=\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }

    static func rejoinWrappedLines(_ text: String) -> String {
        let pattern = "([a-zA-Z,\\x{201D}\\x{2019}\"\u{201C}\u{201D}\u{2018}\u{2019}'])\\n([a-z(])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1 $2")
    }

    static func collapseBlankLineRuns(_ text: String) -> String {
        let pattern = #"\n{3,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n\n")
    }

    static func collapseExtraWhitespace(_ text: String) -> String {
        let pattern = #"[^\S\n]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
    }
}

// ---------------------------------------------------------------------------
// Header detection (mirrors CheckEngine.detectRepeatingHeaders)
// ---------------------------------------------------------------------------

func detectRepeatingHeaders(document: PDFDocument) -> Set<String> {
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

func countOrphanedPunctuation(in text: String) -> Int {
    let pattern = #"\n[ \t]*[.,;:!?][ \t]*(?=\n|$)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
    let range = NSRange(location: 0, length: (text as NSString).length)
    return regex.numberOfMatches(in: text, range: range)
}

// ---------------------------------------------------------------------------
// Test PDFs
// ---------------------------------------------------------------------------

// Map label -> filename prefix for fuzzy matching (filenames contain Unicode quotes)
let testPDFPrefixes: [(prefix: String, label: String)] = [
    ("Neuroscience Of Mind Empowerment", "Neuroscience"),
    ("Entangled Life", "Entangled Life"),
    ("Ethics and Issues in Contemporary Nursing", "Ethics Nursing"),
    ("Guesstimation", "Guesstimation"),
    ("Sources of Power", "Sources of Power"),
    ("TheMindIlluminated", "Mind Illuminated"),
]

let testDir = "/Users/aidan/Downloads/TestPDFs"
let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: testDir)) ?? []

var testPDFs: [(path: String, label: String)] = []
for (prefix, label) in testPDFPrefixes {
    if let match = allFiles.first(where: { $0.hasPrefix(prefix) && $0.hasSuffix(".pdf") }) {
        testPDFs.append((path: testDir + "/" + match, label: label))
    } else {
        print("WARNING: No file found matching prefix '\(prefix)'")
    }
}

let separator = String(repeating: "=", count: 80)
let thinSep = String(repeating: "-", count: 80)

print(separator)
print("DraftSmith PDF Pipeline Test")
print("Header Stripping | Cross-Page Merge | Orphaned Punctuation")
print(separator)

struct PageText {
    let pageIndex: Int
    let normalized: String
}

struct CheckChunk {
    let pageIndices: [Int]
    let text: String
}

for (path, label) in testPDFs {
    print()
    print(thinSep)
    print("PDF: \(label)")

    guard FileManager.default.fileExists(atPath: path) else {
        print("  ERROR: File not found")
        continue
    }

    let url = URL(fileURLWithPath: path)
    guard let document = PDFDocument(url: url) else {
        print("  ERROR: Could not open PDF")
        continue
    }

    let pageCount = document.pageCount
    print("  Total pages: \(pageCount)")

    // Quick text check
    var pagesWithTextCount = 0
    for i in 0..<min(10, pageCount) {
        if let page = document.page(at: i),
           let text = page.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pagesWithTextCount += 1
        }
    }
    if pagesWithTextCount == 0 {
        print("  SKIPPED: No extractable text (scanned/image PDF)")
        continue
    }

    // --- Fix 1: Header detection ---
    let headers = detectRepeatingHeaders(document: document)
    print("  Headers/footers detected: \(headers.count)")
    for h in headers.sorted().prefix(8) {
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

print()
print(separator)
print("Pipeline test complete.")
