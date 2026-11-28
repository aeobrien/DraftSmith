import XCTest
@testable import DraftSmith

final class PDFTextNormalizerTests: XCTestCase {

    // MARK: - Hyphenated Line Breaks

    func testRejoinsHyphenatedWordAcrossNewline() {
        let input = "This is pro-\ngramming text"
        let expected = "This is programming text"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsHyphenatedWordWithSpacesBeforeNewline() {
        let input = "This is pro-  \ngramming text"
        let expected = "This is programming text"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsHyphenatedWordWithSpacesAfterNewline() {
        let input = "This is pro-\n  gramming text"
        let expected = "This is programming text"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsWithCarriageReturnNewline() {
        let input = "This is pro-\r\ngramming text"
        let expected = "This is programming text"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesIntentionalHyphens() {
        // "well-known" on the same line should NOT be joined
        let input = "This is a well-known fact"
        let expected = "This is a well-known fact"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesHyphenBeforeCapitalLetter() {
        // Hyphen + newline + capital letter = likely a proper noun or sentence start
        let input = "See the Anglo-\nSaxon heritage"
        let expected = "See the Anglo-\nSaxon heritage"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testMultipleHyphenatedBreaks() {
        let input = "The pro-\ngramming lan-\nguage is excellent"
        let expected = "The programming language is excellent"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    // MARK: - Soft Hyphens

    func testRemovesSoftHyphens() {
        let input = "pro\u{00AD}gramming"
        let expected = "programming"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    // MARK: - Ligatures

    func testNormalizesfiLigature() {
        let input = "The \u{FB01}rst \u{FB01}nding"
        let expected = "The first finding"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testNormalizesflLigature() {
        let input = "a \u{FB02}ow of \u{FB02}uid"
        let expected = "a flow of fluid"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testNormalizesffLigature() {
        let input = "an e\u{FB00}ective o\u{FB00}er"
        let expected = "an effective offer"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testNormalizesffiLigature() {
        let input = "the o\u{FB03}ce sta\u{FB03}ng"
        let expected = "the office staffing"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testNormalizesfflLigature() {
        let input = "a ba\u{FB04}ed look"
        let expected = "a baffled look"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    // MARK: - Standalone Page Numbers

    func testRemovesStandalonePageNumber() {
        let input = "End of paragraph.\n42\nStart of next."
        let expected = "End of paragraph.\n\nStart of next."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRemovesPageNumberAtStart() {
        let input = "7\nThis is page seven."
        let expected = "\nThis is page seven."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRemovesPageNumberWithSurroundingWhitespace() {
        let input = "End of text.\n  123  \nMore text."
        let expected = "End of text.\n\nMore text."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesNumbersInText() {
        // Numbers that are part of a sentence should NOT be removed
        let input = "There are 42 cats in the house."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), input)
    }

    func testPreservesLargeNumbers() {
        // 4+ digit numbers on their own line are likely not page numbers
        let input = "text\n1234\nmore text"
        XCTAssertTrue(PDFTextNormalizer.normalize(input).contains("1234"))
    }

    // MARK: - Orphaned Punctuation

    func testMergesOrphanedPeriod() {
        let input = "end of sentence\n."
        let expected = "end of sentence."
        XCTAssertEqual(PDFTextNormalizer.mergeOrphanedPunctuation(input), expected)
    }

    func testMergesOrphanedComma() {
        let input = "a list item\n,\nanother item"
        let expected = "a list item,\nanother item"
        XCTAssertEqual(PDFTextNormalizer.mergeOrphanedPunctuation(input), expected)
    }

    func testMergesOrphanedPunctuationWithWhitespace() {
        let input = "some text\n  ;\nmore text"
        let expected = "some text;\nmore text"
        XCTAssertEqual(PDFTextNormalizer.mergeOrphanedPunctuation(input), expected)
    }

    func testDoesNotMergeNonPunctuationLines() {
        let input = "some text\nword\nmore text"
        XCTAssertEqual(PDFTextNormalizer.mergeOrphanedPunctuation(input), input)
    }

    func testMergesMultipleOrphanedPunctuation() {
        let input = "first\n.\nsecond\n!\nthird"
        let expected = "first.\nsecond!\nthird"
        XCTAssertEqual(PDFTextNormalizer.mergeOrphanedPunctuation(input), expected)
    }

    func testOrphanedPunctuationInFullNormalize() {
        // Orphaned period should merge, then wrapped line rejoining can work
        let input = "the end of the paragraph\n.\nThe next paragraph begins"
        let result = PDFTextNormalizer.normalize(input)
        XCTAssertTrue(result.contains("paragraph."), "Expected orphaned period to merge: got \(result)")
    }

    // MARK: - Wrapped Line Rejoining

    func testRejoinsWrappedLine() {
        let input = "The quick brown fox jumped over\nthe lazy dog."
        let expected = "The quick brown fox jumped over the lazy dog."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsAfterComma() {
        let input = "In this case,\nthe answer is clear."
        let expected = "In this case, the answer is clear."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsBeforeParen() {
        let input = "the organism\n(see Chapter 3) is complex."
        let expected = "the organism (see Chapter 3) is complex."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesNewlineBeforeUppercase() {
        // New sentence starting with uppercase = paragraph or sentence boundary
        let input = "End of sentence.\nStart of new sentence."
        let expected = "End of sentence.\nStart of new sentence."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesBlankLineParagraphBreaks() {
        let input = "End of paragraph.\n\nStart of new paragraph."
        let expected = "End of paragraph.\n\nStart of new paragraph."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsMultipleWrappedLines() {
        let input = "Fungi are metabolic wizards and can explore,\nscavenge, and salvage ingeniously, their abilities\nrivaled only by bacteria."
        let expected = "Fungi are metabolic wizards and can explore, scavenge, and salvage ingeniously, their abilities rivaled only by bacteria."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testRejoinsAfterClosingSmartQuote() {
        let input = "he said \u{201D}\nand then left."
        let expected = "he said \u{201D} and then left."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    // MARK: - Blank Line Runs

    func testCollapsesExcessiveBlankLines() {
        let input = "Paragraph one.\n\n\n\n\nParagraph two."
        let expected = "Paragraph one.\n\nParagraph two."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesDoubleNewline() {
        let input = "Paragraph one.\n\nParagraph two."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), input)
    }

    // MARK: - Extra Whitespace

    func testCollapsesExtraSpaces() {
        let input = "This  has   extra    spaces"
        let expected = "This has extra spaces"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testPreservesSingleSpaces() {
        let input = "Normal text with single spaces"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), input)
    }

    func testPreservesNewlines() {
        // Uppercase starts = not rejoined; single newlines between uppercase-starting lines preserved
        let input = "Line one.\nLine two.\nLine three."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), input)
    }

    // MARK: - Combined

    func testCombinedNormalization() {
        let input = "The pro-\ngramming  lan-\nguage\u{00AD}spec"
        let expected = "The programming languagespec"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testCombinedAllPasses() {
        // Hyphenation + ligature + page number + wrapped lines + extra whitespace
        let input = "The e\u{FB00}ective pro-\ngramming  technique was\nelegant and simple.\n42\nNext section begins."
        let expected = "The effective programming technique was elegant and simple.\n\nNext section begins."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testEmptyString() {
        XCTAssertEqual(PDFTextNormalizer.normalize(""), "")
    }

    func testNoChangesNeeded() {
        let input = "This is perfectly normal text."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), input)
    }

    // MARK: - Real-world PDF Patterns

    func testEntangledLifeStyleWrapping() {
        // From Entangled Life: body text wrapped at page margin
        let input = "fascination or distraction to an animal nose. Truffles must be pungent\nenough for their scent to penetrate the layers of soil and enter the air,"
        let expected = "fascination or distraction to an animal nose. Truffles must be pungent enough for their scent to penetrate the layers of soil and enter the air,"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testEthicsTextbookHyphenation() {
        // From Ethics: heavy use of hyphenated line breaks in academic text
        let input = "the profession's first description of its social\nresponsibility. We can use both this document and a subsequent revi-\nsion as a framework."
        let expected = "the profession's first description of its social responsibility. We can use both this document and a subsequent revision as a framework."
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }

    func testGuesstimationPageNumber() {
        // From Guesstimation: standalone page number between paragraphs
        let input = "This system is called scientific notation.\n12\nChapter 2 Dealing with Large Numbers"
        let expected = "This system is called scientific notation.\n\nChapter 2 Dealing with Large Numbers"
        XCTAssertEqual(PDFTextNormalizer.normalize(input), expected)
    }
}
