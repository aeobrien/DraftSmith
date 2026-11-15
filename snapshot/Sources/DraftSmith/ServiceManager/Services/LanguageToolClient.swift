import Foundation

actor LanguageToolClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppConstants.languageToolBaseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    /// Maximum text length per request. LanguageTool's local server defaults to ~20k;
    /// we stay under that to avoid HTTP 413 / 500 errors on dense pages.
    private static let maxTextLength = 15_000

    func check(
        text: String,
        language: String = AppConstants.languageToolLanguage,
        enabledRules: [String] = [],
        disabledRules: [String] = [],
        enabledCategories: [String] = [],
        disabledCategories: [String] = [],
        level: String = "default"
    ) async throws -> LanguageToolResponse {
        // Sanitize: remove null bytes and other control characters that break LanguageTool
        let sanitized = Self.sanitize(text)

        // If text exceeds the limit, split into chunks and merge results
        if sanitized.count > Self.maxTextLength {
            return try await checkInChunks(
                text: sanitized,
                language: language,
                enabledRules: enabledRules,
                disabledRules: disabledRules,
                enabledCategories: enabledCategories,
                disabledCategories: disabledCategories,
                level: level
            )
        }

        return try await performCheck(
            text: sanitized,
            language: language,
            enabledRules: enabledRules,
            disabledRules: disabledRules,
            enabledCategories: enabledCategories,
            disabledCategories: disabledCategories,
            level: level,
            offsetAdjustment: 0
        )
    }

    /// Splits oversized text at sentence boundaries and merges results,
    /// adjusting match offsets to reflect the original text positions.
    private func checkInChunks(
        text: String,
        language: String,
        enabledRules: [String],
        disabledRules: [String],
        enabledCategories: [String],
        disabledCategories: [String],
        level: String
    ) async throws -> LanguageToolResponse {
        let chunks = Self.splitAtSentenceBoundaries(text, maxLength: Self.maxTextLength)
        var allMatches: [LanguageToolMatch] = []
        var lastSoftware: LanguageToolSoftware?
        var lastLanguage: LanguageToolLanguageInfo?
        var chunkStart = 0

        for chunk in chunks {
            let result = try await performCheck(
                text: chunk,
                language: language,
                enabledRules: enabledRules,
                disabledRules: disabledRules,
                enabledCategories: enabledCategories,
                disabledCategories: disabledCategories,
                level: level,
                offsetAdjustment: chunkStart
            )
            allMatches.append(contentsOf: result.matches)
            lastSoftware = result.software
            lastLanguage = result.language
            chunkStart += chunk.count
        }

        return LanguageToolResponse(
            software: lastSoftware,
            language: lastLanguage,
            matches: allMatches
        )
    }

    private func performCheck(
        text: String,
        language: String,
        enabledRules: [String],
        disabledRules: [String],
        enabledCategories: [String],
        disabledCategories: [String],
        level: String,
        offsetAdjustment: Int
    ) async throws -> LanguageToolResponse {
        let url = baseURL.appendingPathComponent("v2/check")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "level", value: level)
        ]
        if !enabledRules.isEmpty {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "enabledRules", value: enabledRules.joined(separator: ","))
            )
        }
        if !disabledRules.isEmpty {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "disabledRules", value: disabledRules.joined(separator: ","))
            )
        }
        if !enabledCategories.isEmpty {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "enabledCategories", value: enabledCategories.joined(separator: ","))
            )
        }
        if !disabledCategories.isEmpty {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "disabledCategories", value: disabledCategories.joined(separator: ","))
            )
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data.prefix(500), encoding: .utf8) ?? "(unreadable)"
            throw DraftSmithError.languageToolRequestFailed(
                "HTTP \(statusCode): \(body)"
            )
        }

        do {
            let decoder = JSONDecoder()
            var result = try decoder.decode(LanguageToolResponse.self, from: data)
            // Adjust offsets if this was a chunk of a larger text
            if offsetAdjustment > 0 {
                result.matches = result.matches.map { match in
                    var adjusted = match
                    adjusted.offset += offsetAdjustment
                    return adjusted
                }
            }
            return result
        } catch {
            throw DraftSmithError.languageToolResponseParseFailed
        }
    }

    /// Remove null bytes and control characters (except newlines/tabs) that can cause
    /// LanguageTool to return HTTP 500 errors.
    private static func sanitize(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            // Keep printable characters, newlines, tabs, and carriage returns
            scalar == "\n" || scalar == "\r" || scalar == "\t" || scalar.value >= 0x20
        }.map(String.init).joined()
    }

    /// Split text at sentence boundaries (. ! ? followed by whitespace) to stay under maxLength.
    private static func splitAtSentenceBoundaries(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(String(remaining))
                break
            }

            // Look for the last sentence boundary within maxLength
            let searchEnd = remaining.index(remaining.startIndex, offsetBy: maxLength)
            let searchRange = remaining.startIndex..<searchEnd
            let searchSlice = remaining[searchRange]

            // Find last sentence-ending punctuation followed by space
            var splitIndex: String.Index?
            for terminator in [". ", "! ", "? ", ".\n", "!\n", "?\n"] {
                if let range = searchSlice.range(of: terminator, options: .backwards) {
                    let candidate = range.upperBound
                    if splitIndex == nil || candidate > splitIndex! {
                        splitIndex = candidate
                    }
                }
            }

            let breakAt = splitIndex ?? searchEnd
            chunks.append(String(remaining[remaining.startIndex..<breakAt]))
            remaining = remaining[breakAt...]
        }

        return chunks
    }

    func isAvailable() async -> Bool {
        let url = baseURL.appendingPathComponent("v2/languages")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}
