import Foundation
@testable import apfel_clip

actor MockActionExecutor: ClipActionExecuting {
    var nextResult: String = "Mock result"
    var nextError: (any Error)?

    func setNextResult(_ result: String) { nextResult = result }
    func setNextError(_ error: (any Error)?) { nextError = error }

    func run(action: ClipAction, input: String) async throws -> String {
        if let nextError { throw nextError }
        return nextResult
    }

    func runCustom(prompt: String, input: String) async throws -> String {
        if let nextError { throw nextError }
        return nextResult
    }
}
