import Foundation
@testable import apfel_clip

@MainActor
final class MockClipboardService: ClipboardService {
    var currentText: String?
    var isCurrentClipboardSensitive = false
    var onExternalChange: ((String?) -> Void)?
    var setTextCalls: [String] = []

    func start() {}
    func stop() {}

    func refreshNow() {
        onExternalChange?(currentText)
    }

    func setText(_ text: String) {
        currentText = text
        setTextCalls.append(text)
    }
}
