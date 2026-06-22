import Foundation

/// Handles batch export/import of PDF comments for external rewriting via Microsoft Copilot.
///
/// Export produces a JSON payload containing all annotations (comments) with a baked-in prompt.
/// Import parses the Copilot response and stores rewritten text as suggestions that the user
/// can accept or dismiss via the existing CommentSidebarView suggestion UI.
enum CopilotExportService {

    // MARK: - Export

    /// Builds a JSON string containing all provided annotations with instructions for Copilot.
    ///
    /// - Parameters:
    ///   - annotations: The PDF annotations (comments) to export.
    ///   - issues: All current issues, used to enrich exported items with category/message when
    ///     an annotation is linked to an issue.
    static func exportJSON(annotations: [DSAnnotation], issues: [Issue] = []) -> String {
        // Build a lookup from annotation UUID to the issue that created it
        let issuesByAnnotationUUID: [UUID: Issue] = {
            var map: [UUID: Issue] = [:]
            for issue in issues {
                if let uuid = issue.annotationUUID {
                    map[uuid] = issue
                }
            }
            return map
        }()

        let exportItems: [[String: String]] = annotations.map { annotation in
            var item: [String: String] = [
                "id": annotation.id.uuidString,
                "context": "", // Populated below if linked to an issue
                "comment": annotation.commentText
            ]
            if let linkedIssue = issuesByAnnotationUUID[annotation.id] {
                item["context"] = linkedIssue.selectionText
                if let category = linkedIssue.category {
                    item["category"] = category
                }
                item["original_message"] = linkedIssue.message
                if let firstSuggestion = linkedIssue.suggestionsList.first {
                    item["suggestion"] = firstSuggestion
                }
            }
            return item
        }

        guard let itemsData = try? JSONSerialization.data(
            withJSONObject: exportItems,
            options: [.prettyPrinted, .sortedKeys]
        ),
              let itemsString = String(data: itemsData, encoding: .utf8) else {
            return "{}"
        }

        let instructions = """
            You are a professional copyeditor reviewing feedback comments on a manuscript. \
            For each comment below, rewrite it into a diplomatic, constructive margin note \
            suitable for an author. Keep the meaning but make it warm, professional, and \
            actionable. The 'context' shows the flagged text (if available), 'category' \
            indicates what kind of issue prompted the comment, 'original_message' explains \
            the problem, and 'suggestion' provides a possible correction. Respond with ONLY \
            a JSON object in the same format, adding a 'rewritten' field to each item.
            """
        let escaped = instructions
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
        {
          "instructions": "\(escaped)",
          "comments": \(itemsString)
        }
        """
    }

    // MARK: - Import

    /// Result of an import operation.
    struct ImportResult {
        let matched: Int
        let total: Int
    }

    /// Parses a JSON response from Copilot and stores rewritten text as suggestions on
    /// matching annotations. The user can then accept or dismiss each suggestion via the
    /// existing CommentSidebarView UI.
    ///
    /// Expected format:
    /// ```json
    /// { "comments": [{ "id": "uuid", "rewritten": "the polished comment" }, ...] }
    /// ```
    ///
    /// Returns a tuple of (matched, total) counts.
    @MainActor
    static func importJSON(
        _ json: String,
        annotations: [DSAnnotation],
        documentManager: PDFDocumentManager
    ) -> ImportResult {
        guard let data = json.data(using: .utf8) else {
            return ImportResult(matched: 0, total: 0)
        }

        // Try to parse — accept both "comments" and legacy "issues" key
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = (root["comments"] as? [[String: Any]])
                ?? (root["issues"] as? [[String: Any]]) else {
            return ImportResult(matched: 0, total: 0)
        }

        let annotationsByID = Dictionary(uniqueKeysWithValues: annotations.map { ($0.id.uuidString, $0) })

        var matched = 0

        for item in items {
            guard let idString = item["id"] as? String,
                  let rewritten = item["rewritten"] as? String,
                  !rewritten.isEmpty else {
                continue
            }

            if let annotation = annotationsByID[idString] {
                // Only suggest if meaningfully different from the current text
                guard rewritten.lowercased() != annotation.commentText.lowercased() else {
                    continue
                }
                // Store as a suggestion — the user can accept or dismiss via the sidebar
                documentManager.rewriteSuggestions[annotation.id] = rewritten
                matched += 1
            }
        }

        return ImportResult(matched: matched, total: items.count)
    }
}
