import Foundation
import Testing
@testable import apfel_clip

@Suite("ApfelClipService")
struct ApfelClipServiceTests {
    @Test("Builds request body with system and user messages")
    func requestBody() {
        let service = ApfelClipService(baseURL: URL(string: "http://127.0.0.1:11435")!)
        let request = service.buildRequest(systemPrompt: "Be helpful", userMessage: "Hello")

        #expect(request.model == "apple-foundationmodel")
        #expect(request.stream == false)
        #expect(request.messages.count == 2)
        #expect(request.messages[0].role == "system")
        #expect(request.messages[0].content == "Be helpful")
        #expect(request.messages[1].role == "user")
        #expect(request.messages[1].content == "Hello")
    }

    @Test("Maps user-facing errors")
    func userFacingErrors() {
        #expect(ApfelClipService.userFacingError("guardrail triggered").contains("safety"))
        #expect(ApfelClipService.userFacingError("context length exceeded").contains("context"))
        #expect(ApfelClipService.userFacingError("rate limit reached").contains("Rate"))
        #expect(ApfelClipService.userFacingError("plain error") == "plain error")
    }
}
