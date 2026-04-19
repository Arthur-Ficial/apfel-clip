import Foundation
import Testing
@testable import apfel_clip

@Suite("PopoverViewModel")
@MainActor
struct PopoverViewModelTests {
    private func makeViewModel() -> (
        PopoverViewModel,
        MockActionExecutor,
        MockClipboardService,
        MockHistoryStore,
        MockClipboardHistoryStore,
        MockSettingsStore,
        MockLaunchAtLoginController
    ) {
        let executor = MockActionExecutor()
        let clipboard = MockClipboardService()
        let historyStore = MockHistoryStore()
        let clipboardHistoryStore = MockClipboardHistoryStore()
        let settingsStore = MockSettingsStore()
        let launchAtLoginController = MockLaunchAtLoginController()
        let viewModel = PopoverViewModel(
            actionExecutor: executor,
            clipboardService: clipboard,
            historyStore: historyStore,
            clipboardHistoryStore: clipboardHistoryStore,
            settingsStore: settingsStore,
            launchAtLoginController: launchAtLoginController
        )
        return (viewModel, executor, clipboard, historyStore, clipboardHistoryStore, settingsStore, launchAtLoginController)
    }

    @Test("Loads persisted settings and history")
    func loadPersistedState() async throws {
        let (viewModel, _, _, historyStore, clipboardHistoryStore, settingsStore, _) = makeViewModel()
        try await historyStore.save([
            ClipHistoryEntry(actionID: "fix-grammar", actionName: "Fix grammar", input: "teh", output: "the")
        ])
        try await clipboardHistoryStore.save([
            ClipboardHistoryEntry(text: "copied", contentType: .text)
        ], limit: 40)
        await settingsStore.save(
            ClipSettings(autoCopy: false, recentCustomPrompts: ["haiku"], preferredPanel: .history)
        )

        await viewModel.loadPersistedState()

        #expect(viewModel.history.count == 1)
        #expect(viewModel.clipboardHistory.count == 1)
        #expect(viewModel.settings.autoCopy == false)
        #expect(viewModel.screen == .history)
    }

    @Test("Running an action stores a result without auto-copying by default")
    func runActionSuccess() async throws {
        let (viewModel, executor, clipboard, historyStore, _, _, _) = makeViewModel()
        await executor.setNextResult("Fixed text")
        clipboard.currentText = "teh text"
        viewModel.refreshFromClipboard()

        let result = try await viewModel.runAction(id: "fix-grammar")

        #expect(result.output == "Fixed text")
        #expect(viewModel.screen == .result)
        #expect(viewModel.history.count == 1)
        #expect(clipboard.setTextCalls.isEmpty) // autoCopy defaults to false
        let saved = try await historyStore.load()
        #expect(saved.count == 1)
    }

    @Test("Running an action auto-copies when autoCopy is enabled")
    func runActionAutoCopiesToClipboard() async throws {
        let (viewModel, executor, clipboard, _, _, settingsStore, _) = makeViewModel()
        await settingsStore.save(ClipSettings(autoCopy: true))
        await viewModel.loadPersistedState()
        await executor.setNextResult("Fixed text")
        clipboard.currentText = "teh text"
        viewModel.refreshFromClipboard()

        _ = try await viewModel.runAction(id: "fix-grammar")

        #expect(clipboard.setTextCalls.last == "Fixed text")
    }

    @Test("Failed action leaves error banner")
    func runActionFailure() async throws {
        let (viewModel, executor, clipboard, _, _, _, _) = makeViewModel()
        await executor.setNextError(ClipServiceError.serverError("Boom"))
        clipboard.currentText = "teh text"
        viewModel.refreshFromClipboard()

        await #expect(throws: ClipServiceError.self) {
            try await viewModel.runAction(id: "fix-grammar")
        }

        #expect(viewModel.banner?.style == .error)
        #expect(viewModel.history.isEmpty)
    }

    @Test("Custom prompt stores prompt in recents")
    func customPromptRecents() async throws {
        let (viewModel, executor, clipboard, _, _, settingsStore, _) = makeViewModel()
        await executor.setNextResult("Pirate text")
        clipboard.currentText = "hello"
        viewModel.refreshFromClipboard()
        viewModel.customPrompt = "Translate to pirate"

        let result = try await viewModel.runCustomPrompt()

        #expect(result.output == "Pirate text")
        #expect(viewModel.settings.recentCustomPrompts.first == "Translate to pirate")
        let loaded = await settingsStore.load()
        #expect(loaded.recentCustomPrompts.first == "Translate to pirate")
    }

    @Test("Action manager favorites and hides actions")
    func actionManager() async throws {
        let (viewModel, _, _, _, _, settingsStore, _) = makeViewModel()

        await viewModel.toggleFavorite("fix-grammar")
        await viewModel.toggleHidden("translate-ja")

        #expect(viewModel.isFavorite("fix-grammar"))
        #expect(viewModel.isHidden("translate-ja"))
        #expect(!viewModel.availableActions.contains(where: { $0.id == "translate-ja" }))
        #expect(viewModel.availableActions.first?.id == "fix-grammar")

        let loaded = await settingsStore.load()
        #expect(loaded.favoriteActionIDs.contains("fix-grammar"))
        #expect(loaded.hiddenActionIDs.contains("translate-ja"))
    }

    @Test("Opening history entry shows result without copying to clipboard")
    func openHistoryEntry() {
        let (viewModel, _, clipboard, _, _, _, _) = makeViewModel()
        let entry = ClipHistoryEntry(
            actionID: "summarize",
            actionName: "Summarize",
            input: "Long",
            output: "Short"
        )

        viewModel.openHistoryEntry(entry)

        #expect(viewModel.result?.output == "Short")
        #expect(viewModel.screen == .result)
        #expect(viewModel.result?.copiedToClipboard == false)
        #expect(clipboard.setTextCalls.isEmpty) // must NOT auto-copy on history open
    }

    @Test("Launch at login defaults on and can be changed")
    func launchAtLoginSetting() async {
        let (viewModel, _, _, _, _, settingsStore, launchAtLoginController) = makeViewModel()

        await viewModel.loadPersistedState()
        #expect(viewModel.settings.launchAtLoginEnabled == true)

        await viewModel.updateLaunchAtLogin(false)

        #expect(launchAtLoginController.setCalls == [false])
        #expect(viewModel.settings.launchAtLoginEnabled == false)

        let loaded = await settingsStore.load()
        #expect(loaded.launchAtLoginEnabled == false)
        #expect(loaded.launchAtLoginPromptShown == true)
    }

    // MARK: - Welcome clipboard seed

    @Test("seedWelcomeClipboardIfNeeded seeds example text when history and clipboard are empty")
    func seedWelcomeClipboardWhenEmpty() {
        let (viewModel, _, clipboard, _, _, _, _) = makeViewModel()
        // No history loaded, clipboard is empty — fresh install.
        viewModel.seedWelcomeClipboardIfNeeded()

        #expect(!viewModel.clipboardText.isEmpty)
        #expect(viewModel.clipboardText.contains("apfel-clip"))
        #expect(clipboard.setTextCalls.count == 1)
    }

    @Test("seedWelcomeClipboardIfNeeded does nothing when clipboard already has text")
    func seedWelcomeClipboardSkipsWhenClipboardHasContent() {
        let (viewModel, _, clipboard, _, _, _, _) = makeViewModel()
        clipboard.currentText = "some existing text"
        viewModel.refreshFromClipboard()

        viewModel.seedWelcomeClipboardIfNeeded()

        #expect(clipboard.setTextCalls.isEmpty)
        #expect(viewModel.clipboardText == "some existing text")
    }

    @Test("seedWelcomeClipboardIfNeeded does nothing when history exists")
    func seedWelcomeClipboardSkipsWhenHistoryExists() async throws {
        let (viewModel, _, clipboard, historyStore, _, _, _) = makeViewModel()
        try await historyStore.save([
            ClipHistoryEntry(actionID: "fix-grammar", actionName: "Fix grammar", input: "old", output: "new")
        ])
        await viewModel.loadPersistedState()
        // Clipboard is empty but history is non-empty — returning user.

        viewModel.seedWelcomeClipboardIfNeeded()

        #expect(clipboard.setTextCalls.isEmpty)
    }

    @Test("External clipboard changes are stored separately and deduplicated")
    func externalClipboardHistoryCapture() async throws {
        let (viewModel, _, clipboard, _, clipboardHistoryStore, _, _) = makeViewModel()
        viewModel.attachClipboardListener()

        clipboard.currentText = "first external copy"
        clipboard.refreshNow()
        await Task.yield()
        clipboard.refreshNow()
        await Task.yield()

        #expect(viewModel.clipboardHistory.count == 1)
        #expect(viewModel.clipboardHistory.first?.text == "first external copy")

        let stored = try await clipboardHistoryStore.load(limit: 40)
        #expect(stored.count == 1)
    }

    @Test("Clipboard history limit truncates stored external copies")
    func clipboardHistoryLimitTruncates() async throws {
        let (viewModel, _, clipboard, _, clipboardHistoryStore, settingsStore, _) = makeViewModel()
        await settingsStore.save(ClipSettings(clipboardHistoryLimit: 2))
        await viewModel.loadPersistedState()
        viewModel.attachClipboardListener()

        clipboard.currentText = "one"
        clipboard.refreshNow()
        await Task.yield()
        clipboard.currentText = "two"
        clipboard.refreshNow()
        await Task.yield()
        clipboard.currentText = "three"
        clipboard.refreshNow()
        await Task.yield()

        #expect(viewModel.clipboardHistory.map(\.text) == ["three", "two"])

        let stored = try await clipboardHistoryStore.load(limit: 2)
        #expect(stored.map(\.text) == ["three", "two"])
    }

    @Test("Updating clipboard history limit persists and trims existing items")
    func updateClipboardHistoryLimit() async throws {
        let (viewModel, _, _, _, clipboardHistoryStore, settingsStore, _) = makeViewModel()
        try await clipboardHistoryStore.save([
            ClipboardHistoryEntry(text: "one", contentType: .text),
            ClipboardHistoryEntry(text: "two", contentType: .text),
            ClipboardHistoryEntry(text: "three", contentType: .text),
        ], limit: 40)
        await viewModel.loadPersistedState()

        await viewModel.updateClipboardHistoryLimit(2)

        #expect(viewModel.clipboardHistory.count == 2)
        let loadedSettings = await settingsStore.load()
        #expect(loadedSettings.clipboardHistoryLimit == 2)
        let stored = try await clipboardHistoryStore.load(limit: 40)
        #expect(stored.count == 2)
    }
}
