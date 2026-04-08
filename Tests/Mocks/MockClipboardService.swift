import Foundation
@testable import apfel_clip

@MainActor
final class MockClipboardService: ClipboardService {
    var currentText: String?
    var onExternalChange: ((String?) -> Void)?
    var started = false
    var setTextCalls: [String] = []

    func start() {
        started = true
    }

    func stop() {
        started = false
    }

    func refreshNow() {
        onExternalChange?(currentText)
    }

    func setText(_ text: String) {
        currentText = text
        setTextCalls.append(text)
    }

    func simulateExternalChange(_ text: String?) {
        currentText = text
        onExternalChange?(text)
    }
}
