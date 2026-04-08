import AppKit
import Foundation

@MainActor
final class PasteboardClipboardService: ClipboardService {
    var currentText: String?
    var onExternalChange: ((String?) -> Void)?

    private var lastChangeCount = -1
    private var timer: Timer?
    private var suppressNextPoll = false

    func start() {
        refreshNow()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount
        currentText = pasteboard.string(forType: .string)
        onExternalChange?(currentText)
    }

    func setText(_ text: String) {
        suppressNextPoll = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        currentText = text
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if suppressNextPoll {
            suppressNextPoll = false
            return
        }

        currentText = pasteboard.string(forType: .string)
        onExternalChange?(currentText)
    }
}
