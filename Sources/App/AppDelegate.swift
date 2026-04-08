import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, PopoverPresenting {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var globalMonitor: Any?

    private let clipboardService = PasteboardClipboardService()
    private let actionExecutor = ConfigurableClipActionExecutor()
    private let historyStore = FileHistoryStore()
    private let settingsStore = UserDefaultsSettingsStore()
    private let serverManager = ServerManager()

    private var viewModel: PopoverViewModel?
    private var controlServer: ClipControlServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = PopoverViewModel(
            actionExecutor: actionExecutor,
            clipboardService: clipboardService,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        self.viewModel = viewModel

        configurePopover(viewModel: viewModel)
        configureStatusItem()
        configureHotkey()

        Task {
            await bootstrap(viewModel: viewModel)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardService.stop()
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        controlServer?.stop()
        serverManager.stop()
    }

    func showPopover() {
        guard let statusButton = statusItem?.button,
              let popover else { return }
        if !popover.isShown {
            popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hidePopover() {
        popover?.performClose(nil)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover else { return }
        popover.isShown ? hidePopover() : showPopover()
    }

    private func bootstrap(viewModel: PopoverViewModel) async {
        await viewModel.loadPersistedState()
        viewModel.attachClipboardListener()
        clipboardService.start()
        viewModel.refreshFromClipboard()

        let controlAPI = ClipControlAPI(viewModel: viewModel, presenter: self)
        let controlServer = ClipControlServer(api: controlAPI)
        if let controlPort = controlServer.start() {
            self.controlServer = controlServer
            viewModel.setControlPort(controlPort)
        }

        viewModel.setServerState(.starting)
        if let port = await serverManager.start() {
            await actionExecutor.updateService(ApfelClipService(port: port))
            viewModel.setServerState(.ready(port: port))
        } else {
            viewModel.setServerState(.failed(serverManager.failureMessage ?? "Failed to start apfel"))
            viewModel.showBanner(
                .init(
                    style: .error,
                    title: "Local AI unavailable",
                    detail: serverManager.failureMessage ?? "apfel could not be started."
                )
            )
        }
    }

    private func configurePopover(viewModel: PopoverViewModel) {
        let hostingController = NSHostingController(rootView: PopoverRootView(viewModel: viewModel))
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 540, height: 820)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 540, height: 820)
        popover.contentViewController = hostingController
        self.popover = popover
        popover.delegate = self
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "apfel-clip")
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = statusItem
    }

    private func configureHotkey() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.charactersIgnoringModifiers == "v" else { return }
            Task { @MainActor in
                self?.togglePopover(nil)
            }
        }
    }

    // MARK: - NSPopoverDelegate

    @objc nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.returnToPrimaryPanel()
        }
    }
}
