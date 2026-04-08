import Foundation

struct ClipServerHealth: Codable, Equatable, Sendable {
    let status: String
    let version: String?
    let contextWindow: Int?
    let modelAvailable: Bool
    let supportedLanguages: [String]?

    enum CodingKeys: String, CodingKey {
        case status
        case version
        case contextWindow = "context_window"
        case modelAvailable = "model_available"
        case supportedLanguages = "supported_languages"
    }
}

protocol ClipService: Sendable {
    func healthCheck() async throws -> ClipServerHealth
    func complete(systemPrompt: String, userMessage: String) async throws -> String
}

protocol ClipActionExecuting: Sendable {
    func run(action: ClipAction, input: String) async throws -> String
    func runCustom(prompt: String, input: String) async throws -> String
}

enum ClipServiceError: LocalizedError, Equatable, Sendable {
    case serverError(String)
    case emptyResponse
    case serverUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .emptyResponse:
            return "The model returned an empty response."
        case .serverUnavailable:
            return "Local AI server is unavailable."
        case .invalidResponse:
            return "The local AI server returned an invalid response."
        }
    }
}

enum ClipAppError: LocalizedError, Equatable, Sendable {
    case actionNotFound(String)
    case missingClipboardText
    case missingPrompt
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .actionNotFound(let id):
            return "Unknown action '\(id)'."
        case .missingClipboardText:
            return "Copy some text before running an action."
        case .missingPrompt:
            return "Enter a custom prompt first."
        case .alreadyRunning:
            return "An action is already running."
        }
    }
}
