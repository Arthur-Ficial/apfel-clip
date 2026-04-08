import Foundation

final class ApfelClipService: ClipService, @unchecked Sendable {
    let baseURL: URL
    let modelName: String

    init(baseURL: URL, modelName: String = "apple-foundationmodel") {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    init(port: Int, modelName: String = "apple-foundationmodel") {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
        self.modelName = modelName
    }

    struct ChatRequest: Encodable, Equatable {
        struct Message: Encodable, Equatable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let stream: Bool
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct ResponseMessage: Decodable {
                let role: String
                let content: String
            }

            let message: ResponseMessage
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        let id: String
        let choices: [Choice]
    }

    struct APIError: Decodable {
        struct Detail: Decodable {
            let message: String
        }

        let error: Detail
    }

    func buildRequest(systemPrompt: String, userMessage: String) -> ChatRequest {
        ChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userMessage),
            ],
            stream: false
        )
    }

    func complete(systemPrompt: String, userMessage: String) async throws -> String {
        let request = buildRequest(systemPrompt: systemPrompt, userMessage: userMessage)
        var urlRequest = URLRequest(url: URL(string: "/v1/chat/completions", relativeTo: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClipServiceError.invalidResponse
            }
            if httpResponse.statusCode >= 400 {
                let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
                    ?? String(data: data, encoding: .utf8)
                    ?? "Unknown error"
                throw ClipServiceError.serverError(Self.userFacingError(message))
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !content.isEmpty else {
                throw ClipServiceError.emptyResponse
            }
            return content
        } catch let error as ClipServiceError {
            throw error
        } catch {
            throw ClipServiceError.serverError("Connection failed: \(error.localizedDescription)")
        }
    }

    func healthCheck() async throws -> ClipServerHealth {
        let url = URL(string: "/health", relativeTo: baseURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ClipServiceError.serverUnavailable
        }
        return try JSONDecoder().decode(ClipServerHealth.self, from: data)
    }

    static func userFacingError(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("guardrail") || lowered.contains("safety") || lowered.contains("unsafe") {
            return "Content blocked by on-device safety filters. Try rephrasing."
        }
        if lowered.contains("context") && lowered.contains("exceed") {
            return "Input exceeds the context window. Shorten the clipboard text and try again."
        }
        if lowered.contains("rate limit") {
            return "Rate limited. Wait a moment and try again."
        }
        if lowered.contains("concurrent") || lowered.contains("capacity") {
            return "Server is busy. Try again in a moment."
        }
        return raw
    }
}
