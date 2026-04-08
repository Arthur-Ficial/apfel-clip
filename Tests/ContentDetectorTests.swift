import Testing
@testable import apfel_clip

@Suite("ContentDetector")
struct ContentDetectorTests {
    @Test("Detects JSON")
    func detectJSON() {
        #expect(ContentDetector.detect("{\"a\":1}") == .json)
    }

    @Test("Detects shell commands")
    func detectShell() {
        #expect(ContentDetector.detect("git status") == .shellCommand)
    }

    @Test("Detects errors")
    func detectError() {
        #expect(ContentDetector.detect("fatal: Not a git repository") == .error)
    }

    @Test("Detects code")
    func detectCode() {
        let sample = """
        import Foundation
        struct User {
            let name: String
        }
        """
        #expect(ContentDetector.detect(sample) == .code)
    }

    @Test("Falls back to plain text")
    func detectText() {
        #expect(ContentDetector.detect("This is a normal paragraph.") == .text)
    }
}
