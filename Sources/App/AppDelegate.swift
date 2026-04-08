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
    private let launchAtLoginController = SystemLaunchAtLoginController()
    private let serverManager = ServerManager()

    private var viewModel: PopoverViewModel?
    private var controlServer: ClipControlServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = PopoverViewModel(
            actionExecutor: actionExecutor,
            clipboardService: clipboardService,
            historyStore: historyStore,
            settingsStore: settingsStore,
            launchAtLoginController: launchAtLoginController
        )
        self.viewModel = viewModel

        // Status item and hotkey register immediately so the icon appears at once.
        // Popover is created only after settings are loaded — so the first time the
        // user opens it, their saved actions and preferences are already present.
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

    @objc func showPopover() {
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

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = buildContextMenu()
            sender.menu = menu
            sender.performClick(nil)
            sender.menu = nil
        } else {
            togglePopover(sender)
        }
    }

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open apfel-clip", action: #selector(showPopover), keyEquivalent: "")
        menu.addItem(openItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: viewModel?.settings.launchAtLoginEnabled == true ? "Disable Launch at Login" : "Enable Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        menu.addItem(launchItem)

        let autoCopyItem = NSMenuItem(
            title: viewModel?.settings.autoCopy == true ? "Disable Auto-Copy" : "Enable Auto-Copy",
            action: #selector(toggleAutoCopy),
            keyEquivalent: ""
        )
        menu.addItem(autoCopyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit apfel-clip",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleLaunchAtLogin() {
        guard let viewModel else { return }
        Task {
            await viewModel.updateLaunchAtLogin(!viewModel.settings.launchAtLoginEnabled)
        }
    }

    @objc private func toggleAutoCopy() {
        guard let viewModel else { return }
        Task {
            await viewModel.updateAutoCopy(!viewModel.settings.autoCopy)
        }
    }

    private func bootstrap(viewModel: PopoverViewModel) async {
        // Load settings and history FIRST — popover is created after this so the
        // UI is never shown in an empty-defaults state.
        await viewModel.loadPersistedState()
        configurePopover(viewModel: viewModel)
        await configureLaunchAtLogin(viewModel: viewModel)

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
        hostingController.view.appearance = NSAppearance(named: .aqua)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 540, height: 820)
        popover.contentViewController = hostingController
        popover.appearance = NSAppearance(named: .aqua)
        self.popover = popover
        popover.delegate = self
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "apfel-clip")
            button.imagePosition = .imageOnly
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

    private func configureLaunchAtLogin(viewModel: PopoverViewModel) async {
        if viewModel.settings.launchAtLoginPromptShown {
            await viewModel.applySavedLaunchAtLoginPreference()
            return
        }

        let shouldEnable = promptForLaunchAtLogin()
        await viewModel.completeLaunchAtLoginPrompt(enable: shouldEnable)
    }

    private func promptForLaunchAtLogin() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Start apfel-clip at login?"
        alert.informativeText = "Keep apfel-clip ready in your menu bar every time you sign in. You can change this later in Settings."
        alert.addButton(withTitle: "Enable at Login")
        alert.addButton(withTitle: "Not Now")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - NSPopoverDelegate

    @objc nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.returnToPrimaryPanel()
        }
    }
}
