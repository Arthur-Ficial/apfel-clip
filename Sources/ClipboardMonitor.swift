// ============================================================================
// ClipboardMonitor.swift - Polls NSPasteboard for clipboard changes
// ============================================================================

import AppKit
import Observation

@MainActor
@Observable
final class ClipboardMonitor {
    var currentText: String?
    var hasNewContent = false

    private var lastChangeCount: Int = -1
    private var timer: Timer?
    /// Set to true briefly when WE write to the clipboard, so we don't re-trigger.
    var ignoreNextChange = false

    func start() {
        // Read current clipboard immediately
        lastChangeCount = NSPasteboard.general.changeCount
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            currentText = text
            printStderr("apfel-clip: clipboard has text (\(text.count) chars)")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            currentText = text
            hasNewContent = true
        }
    }

    /// Copy text to clipboard without triggering our own monitor.
    func copyToClipboard(_ text: String) {
        ignoreNextChange = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
