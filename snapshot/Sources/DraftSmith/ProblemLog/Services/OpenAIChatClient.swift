import Foundation

actor OpenAIChatClient {
    private let session = URLSession.shared

    func sendMessages(_ messages: [ProblemLogMessage]) async throws -> String {
        guard let url = URL(string: AppConstants.openAIBaseURL) else {
            throw OpenAIChatError.invalidURL
        }

        let apiKey = AppConstants.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw OpenAIChatError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AppConstants.openAIModel,
            "messages": messages.map { msg in
                [
                    "role": msg.role.rawValue,
                    "content": msg.content
                ]
            }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIChatError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIChatError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIChatError.parseError
        }

        return content
    }
}

enum OpenAIChatError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .missingAPIKey: return "OpenAI API key not configured. Set your key in Settings → Services."
        case .invalidResponse: return "Invalid response from API."
        case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
        case .parseError: return "Failed to parse API response."
        }
    }
}
