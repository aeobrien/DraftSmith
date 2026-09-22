import AppKit

struct ClipboardService {
    func copyToClipboard(subject: String?, body: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var text = ""
        if let subject = subject, !subject.isEmpty {
            text = "Subject: \(subject)\n\n"
        }
        text += body

        pasteboard.setString(text, forType: .string)
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
