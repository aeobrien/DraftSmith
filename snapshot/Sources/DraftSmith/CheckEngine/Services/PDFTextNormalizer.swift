import Foundation

/// Normalizes raw PDF-extracted text before sending to LanguageTool.
///
/// PDF text extraction (via PDFKit's `page.string`) produces artifacts that
/// cause false positives in LanguageTool. This normalizer fixes the most
/// common issues without altering the semantic content.
struct PDFTextNormalizer {

    /// Apply all normalization passes to raw PDF-extracted text.
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

    // MARK: - Passes

    /// Rejoin words split across lines with a hyphen.
    ///
    /// PDF extraction often produces "pro-\ngramming" or "pro- gramming"
    /// for words hyphenated at line breaks. This pass rejoins them.
    ///
    /// Preserves intentional hyphens (e.g., "well-known") by only rejoining
    /// when the hyphen is followed by a newline (with optional spaces/carriage returns).
    static func rejoinHyphenatedLineBreaks(_ text: String) -> String {
        // Match: word character, hyphen, optional spaces, newline, optional spaces, lowercase letter
        // The lowercase letter requirement avoids rejoining at sentence boundaries
        // or where a proper noun starts the next line.
        let pattern = #"(\w)-[ \t]*\r?\n[ \t]*([a-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1$2")
    }

    /// Normalize various dash characters to standard forms.
    ///
    /// PDF extraction can produce inconsistent dash characters. Normalize
    /// em-dashes and en-dashes to their standard Unicode forms with consistent spacing.
    static func normalizeDashes(_ text: String) -> String {
        var result = text
        // Soft hyphens (invisible hyphens used for line-break hints) — remove entirely
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        return result
    }

    /// Replace Unicode ligature characters with their ASCII equivalents.
    ///
    /// Some PDFs embed typographic ligature codepoints (U+FB00..U+FB06) instead
    /// of separate letters. LanguageTool may not recognise these, so we expand them.
    static func normalizeLigatures(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\u{FB00}", with: "ff")   // ﬀ
        result = result.replacingOccurrences(of: "\u{FB01}", with: "fi")   // ﬁ
        result = result.replacingOccurrences(of: "\u{FB02}", with: "fl")   // ﬂ
        result = result.replacingOccurrences(of: "\u{FB03}", with: "ffi")  // ﬃ
        result = result.replacingOccurrences(of: "\u{FB04}", with: "ffl")  // ﬄ
        result = result.replacingOccurrences(of: "\u{FB05}", with: "st")   // ﬅ (long s + t)
        result = result.replacingOccurrences(of: "\u{FB06}", with: "st")   // ﬆ
        return result
    }

    /// Remove standalone page numbers (lines containing only 1-3 digits).
    ///
    /// PDF extraction often includes page numbers as separate lines. These
    /// cause LanguageTool to flag them as sentence fragments.
    static func removeStandalonePageNumbers(_ text: String) -> String {
        let pattern = #"(?m)^\s*\d{1,3}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    /// Merge lines consisting solely of punctuation with the preceding line.
    ///
    /// PDF extraction sometimes places punctuation (period, comma, semicolon,
    /// colon, exclamation, question mark) on its own line. This pass merges
    /// such orphaned punctuation back onto the end of the previous line.
    static func mergeOrphanedPunctuation(_ text: String) -> String {
        // Match: newline followed by optional whitespace then a single punctuation char,
        // then end-of-line (or end-of-string). Replace newline+whitespace with nothing,
        // effectively appending the punctuation to the previous line.
        let pattern = #"\n[ \t]*([.,;:!?])[ \t]*(?=\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }

    /// Rejoin lines that were wrapped by the PDF renderer.
    ///
    /// PDF text is typically wrapped at the page margin. When a line ends
    /// with a word character (not punctuation) and the next line starts with
    /// a lowercase letter or opening paren, the newline was almost certainly
    /// a soft wrap — not a paragraph break. We replace it with a space.
    static func rejoinWrappedLines(_ text: String) -> String {
        // Match: a line ending with a letter/comma/closing-quote, newline,
        // followed by a line starting with a lowercase letter or open-paren.
        // This preserves genuine paragraph breaks (blank lines, lines ending
        // with sentence-terminal punctuation, or next line starting uppercase).
        // Uses ICU regex \x{NNNN} for Unicode smart quotes.
        let pattern = "([a-zA-Z,\\x{201D}\\x{2019}\"\u{201C}\u{201D}\u{2018}\u{2019}'])\\n([a-z(])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1 $2")
    }

    /// Collapse runs of 3+ blank lines to a single blank line.
    ///
    /// PDF extraction between sections or around images can leave large
    /// vertical gaps that produce excessive whitespace in the text.
    static func collapseBlankLineRuns(_ text: String) -> String {
        let pattern = #"\n{3,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n\n")
    }

    /// Collapse runs of whitespace (excluding newlines) to single spaces.
    ///
    /// PDF extraction sometimes inserts extra spaces, especially around
    /// column boundaries or justified text.
    static func collapseExtraWhitespace(_ text: String) -> String {
        let pattern = #"[^\S\n]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
    }
}
