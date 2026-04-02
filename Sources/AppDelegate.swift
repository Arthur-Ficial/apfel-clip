// ============================================================================
// AppDelegate.swift - Menu bar item, popover, server lifecycle, hotkey
// ============================================================================

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var serverProcess: Process?
    private var apiClient: APIClient!
    private var clipboardMonitor: ClipboardMonitor!
    private var actionRunner: ActionRunner!
    private var historyStore: HistoryStore!
    private var globalMonitor: Any?
    private var serverReady = false

    private let port = 11435

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create UI immediately (menu bar icon must appear fast)
        apiClient = APIClient(port: port)
        clipboardMonitor = ClipboardMonitor()
        actionRunner = ActionRunner(apiClient: apiClient)
        historyStore = HistoryStore()

        // Create popover
        let popoverView = PopoverView(
            clipboard: clipboardMonitor,
            runner: actionRunner,
            historyStore: historyStore
        )
        popover = NSPopover()
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.view.setFrameSize(NSSize(width: 320, height: 1))  // width fixed, height auto
        popover.contentViewController = hostingController
        popover.behavior = .transient

        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "apfel-clip")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Register global hotkey: Cmd+Shift+V
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "v" {
                Task { @MainActor in
                    self?.togglePopover(nil)
                }
            }
        }

        printStderr("apfel-clip: menu bar icon ready, popover created")

        // Start server and clipboard monitor in background
        Task {
            guard await startServerAsync() else {
                printStderr("apfel-clip: failed to start server")
                return
            }
            printStderr("apfel-clip: server ready on port \(port)")
            serverReady = true
            clipboardMonitor.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let process = serverProcess, process.isRunning {
            process.terminate()
            printStderr("apfel-clip: server terminated")
        }
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Server Lifecycle

    private func startServerAsync() async -> Bool {
        let apfelPath: String
        if let resolved = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":").map({ "\($0)/apfel" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            apfelPath = resolved
        } else if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/apfel") {
            apfelPath = "/usr/local/bin/apfel"
        } else {
            printStderr("apfel-clip: 'apfel' not found in PATH. Install: brew install Arthur-Ficial/tap/apfel")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: apfelPath)
        process.arguments = ["--serve", "--port", "\(port)", "--cors"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            serverProcess = process
            printStderr("apfel-clip: server started (PID: \(process.processIdentifier))")
        } catch {
            printStderr("apfel-clip: failed to start server: \(error)")
            return false
        }

        // Poll for health
        for _ in 0..<50 {  // 10 seconds max
            if await apiClient.healthCheck() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        printStderr("apfel-clip: server did not become ready within 10 seconds")
        return false
    }
}
