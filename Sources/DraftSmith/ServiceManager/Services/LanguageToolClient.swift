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

    func check(
        text: String,
        language: String = AppConstants.languageToolLanguage,
        enabledRules: [String] = [],
        disabledRules: [String] = [],
        enabledCategories: [String] = [],
        disabledCategories: [String] = [],
        level: String = "default"
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
            throw DraftSmithError.languageToolRequestFailed("HTTP error")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(LanguageToolResponse.self, from: data)
        } catch {
            throw DraftSmithError.languageToolResponseParseFailed
        }
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
