import Foundation

struct LLMResponseParser {
    /// Parses LLM text output into a typed Codable model.
    /// Handles markdown fences, preamble text, missing braces, and trailing commas.
    func parse<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
        let jsonString = extractJSON(from: text)

        guard let data = jsonString.data(using: .utf8) else {
            throw DraftSmithError.llmResponseParseFailed("Could not convert text to data")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Try with trailing comma cleanup
            let cleaned = cleanJSON(jsonString)
            guard let cleanedData = cleaned.data(using: .utf8) else {
                throw DraftSmithError.llmResponseParseFailed("JSON cleanup failed: \(error.localizedDescription)")
            }
            do {
                return try JSONDecoder().decode(T.self, from: cleanedData)
            } catch {
                throw DraftSmithError.llmResponseParseFailed("Parse failed after cleanup: \(error.localizedDescription)")
            }
        }
    }

    /// Extracts JSON from LLM text that may contain markdown fences, preamble, etc.
    func extractJSON(from text: String) -> String {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fences
        if text.contains("```json") {
            if let start = text.range(of: "```json") {
                text = String(text[start.upperBound...])
            }
        } else if text.contains("```") {
            if let start = text.range(of: "```") {
                text = String(text[start.upperBound...])
            }
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the first { and last }
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            // Try to add missing braces
            if text.contains("\"variants\"") || text.contains("\"drafts\"") {
                return "{\(text)}"
            }
            return text
        }

        return String(text[firstBrace...lastBrace])
    }

    /// Cleans common JSON issues from LLM output.
    private func cleanJSON(_ json: String) -> String {
        var result = json

        // Remove trailing commas before closing brackets/braces
        result = result.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )

        // Fix single quotes to double quotes (some models use single quotes)
        // Only do this if there are no double quotes present
        if !result.contains("\"") && result.contains("'") {
            result = result.replacingOccurrences(of: "'", with: "\"")
        }

        return result
    }
}
