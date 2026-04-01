// ============================================================================
// ActionRunner.swift - Executes actions against the apfel server
// Puts the task instruction + text in the user message for best results.
// ============================================================================

import Foundation

@MainActor
@Observable
final class ActionRunner {
    let apiClient: APIClient
    var isRunning = false
    var lastError: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Run an action on the given text.
    func run(action: ClipAction, text: String) async -> String? {
        if action.isLocal {
            return runLocal(action: action, text: text)
        }

        isRunning = true
        lastError = nil
        defer { isRunning = false }

        // Build user message: instruction + text
        let userMessage = "\(action.instruction)\n\n\(text)"

        do {
            let result = try await apiClient.chatCompletion(
                systemPrompt: action.systemPrompt,
                userMessage: userMessage
            )
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Run a custom prompt action.
    func runCustom(prompt: String, text: String) async -> String? {
        isRunning = true
        lastError = nil
        defer { isRunning = false }

        let userMessage = "\(prompt)\n\nINPUT: \(text)"

        do {
            let result = try await apiClient.chatCompletion(
                systemPrompt: "Reply with ONLY the result. No explanations.",
                userMessage: userMessage
            )
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func runLocal(action: ClipAction, text: String) -> String? {
        switch action.id {
        case "pretty-json":
            return prettyFormatJSON(text)
        default:
            return text
        }
    }

    private func prettyFormatJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return text }
        return str
    }
}
