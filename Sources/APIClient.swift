// ============================================================================
// APIClient.swift - HTTP client to apfel --serve
// Simplified from apfel-gui: non-streaming only, no logs/stats.
// ============================================================================

import Foundation

final class APIClient: Sendable {
    let baseURL: URL

    init(port: Int) {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: baseURL) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Chat Completion

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Decodable {
        let id: String
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Decodable {
            let message: ResponseMessage
            let finish_reason: String?
        }
        struct ResponseMessage: Decodable {
            let role: String
            let content: String
        }
        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let total_tokens: Int?
        }
    }

    struct APIError: Decodable {
        let error: ErrorDetail
        struct ErrorDetail: Decodable {
            let message: String
            let type: String?
            let code: String?
        }
    }

    func chatCompletion(systemPrompt: String, userMessage: String) async throws -> String {
        var messages: [ChatRequest.Message] = []
        messages.append(.init(role: "system", content: systemPrompt))
        messages.append(.init(role: "user", content: userMessage))

        let request = ChatRequest(
            model: "apple-foundationmodel",
            messages: messages,
            stream: false
        )

        var urlRequest = URLRequest(url: URL(string: "/v1/chat/completions", relativeTo: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)

        // Check for error response
        if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
            throw ClipError.serverError(apiError.error.message)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw ClipError.emptyResponse
        }
        return content
    }
}

enum ClipError: LocalizedError {
    case serverError(String)
    case emptyResponse
    case serverNotRunning
    case apfelNotFound

    var errorDescription: String? {
        switch self {
        case .serverError(let msg):
            let lowered = msg.lowercased()
            if lowered.contains("unsafe") || lowered.contains("safety") {
                return "Blocked by safety filter. Try different text."
            }
            return msg
        case .emptyResponse:
            return "No response from model."
        case .serverNotRunning:
            return "Server not responding. Restart apfel-clip."
        case .apfelNotFound:
            return "apfel not found. Install: brew install Arthur-Ficial/tap/apfel"
        }
    }
}
