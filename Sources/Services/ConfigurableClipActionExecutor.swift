import Foundation

actor ConfigurableClipActionExecutor: ClipActionExecuting {
    private var service: (any ClipService)?

    func updateService(_ service: (any ClipService)?) {
        self.service = service
    }

    func run(action: ClipAction, input: String) async throws -> String {
        if let localAction = action.localAction {
            return try runLocal(localAction, input: input)
        }

        guard let service else {
            throw ClipServiceError.serverUnavailable
        }

        let userMessage = "\(action.instruction)\n\n\(input)"
        let result = try await service.complete(
            systemPrompt: action.systemPrompt,
            userMessage: userMessage
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runCustom(prompt: String, input: String) async throws -> String {
        guard let service else {
            throw ClipServiceError.serverUnavailable
        }
        let result = try await service.complete(
            systemPrompt: "Apply the user's instruction to the input and reply with only the transformed result.",
            userMessage: "\(prompt)\n\nINPUT:\n\(input)"
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runLocal(_ action: ClipLocalAction, input: String) throws -> String {
        switch action {
        case .prettyJSON:
            guard let data = input.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data),
                  let formatted = try? JSONSerialization.data(
                      withJSONObject: jsonObject,
                      options: [.prettyPrinted, .sortedKeys]
                  ),
                  let output = String(data: formatted, encoding: .utf8) else {
                throw ClipServiceError.serverError("Clipboard text is not valid JSON.")
            }
            return output
        }
    }
}
