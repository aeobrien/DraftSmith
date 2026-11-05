import XCTest
import AppKit
@testable import DraftSmith

final class ClipboardServiceTests: XCTestCase {

    private let service = ClipboardService()

    // MARK: - Copy Plain Text

    func testCopyToClipboard_plainText() {
        let text = "This is a test comment for the PDF annotation."

        service.copyToClipboard(text)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, text)
    }

    func testCopyToClipboard_emptyString() {
        service.copyToClipboard("")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "")
    }

    func testCopyToClipboard_unicodeText() {
        let text = "Caf\u{00E9} r\u{00E9}sum\u{00E9} \u{2014} na\u{00EF}ve \u{1F4DD}"

        service.copyToClipboard(text)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, text)
    }

    func testCopyToClipboard_multilineText() {
        let text = """
        Line one
        Line two
        Line three
        """

        service.copyToClipboard(text)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, text)
    }

    // MARK: - Copy Subject + Body

    func testCopyToClipboard_subjectAndBody() {
        service.copyToClipboard(subject: "Meeting Follow-up", body: "Dear colleague, please find the notes attached.")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Subject: Meeting Follow-up"))
        XCTAssertTrue(result!.contains("Dear colleague, please find the notes attached."))
    }

    func testCopyToClipboard_nilSubject_omitsSubjectLine() {
        service.copyToClipboard(subject: nil, body: "Just the body text.")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)

        XCTAssertEqual(result, "Just the body text.")
        XCTAssertFalse(result!.contains("Subject:"))
    }

    func testCopyToClipboard_emptySubject_omitsSubjectLine() {
        service.copyToClipboard(subject: "", body: "Body only.")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)

        XCTAssertEqual(result, "Body only.")
    }

    func testCopyToClipboard_subjectAndBody_formatIncludesBlankLine() {
        service.copyToClipboard(subject: "Re: Draft Review", body: "Please review.")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)!

        // Format should be: "Subject: ...\n\nbody"
        XCTAssertTrue(result.hasPrefix("Subject: Re: Draft Review\n\n"))
    }

    // MARK: - Overwrite Behavior

    func testCopyToClipboard_overwritesPreviousContent() {
        service.copyToClipboard("First copy")
        service.copyToClipboard("Second copy")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "Second copy")
    }
}
