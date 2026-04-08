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
        MockSettingsStore
    ) {
        let executor = MockActionExecutor()
        let clipboard = MockClipboardService()
        let historyStore = MockHistoryStore()
        let settingsStore = MockSettingsStore()
        let viewModel = PopoverViewModel(
            actionExecutor: executor,
            clipboardService: clipboard,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        return (viewModel, executor, clipboard, historyStore, settingsStore)
    }

    @Test("Loads persisted settings and history")
    func loadPersistedState() async throws {
        let (viewModel, _, _, historyStore, settingsStore) = makeViewModel()
        try await historyStore.save([
            ClipHistoryEntry(actionID: "fix-grammar", actionName: "Fix grammar", input: "teh", output: "the")
        ])
        await settingsStore.save(
            ClipSettings(autoCopy: false, recentCustomPrompts: ["haiku"], preferredPanel: .history)
        )

        await viewModel.loadPersistedState()

        #expect(viewModel.history.count == 1)
        #expect(viewModel.settings.autoCopy == false)
        #expect(viewModel.screen == .history)
    }

    @Test("Running an action stores a result and auto-copies it")
    func runActionSuccess() async throws {
        let (viewModel, executor, clipboard, historyStore, _) = makeViewModel()
        await executor.setNextResult("Fixed text")
        clipboard.currentText = "teh text"
        viewModel.refreshFromClipboard()

        let result = try await viewModel.runAction(id: "fix-grammar")

        #expect(result.output == "Fixed text")
        #expect(viewModel.screen == .result)
        #expect(viewModel.history.count == 1)
        #expect(clipboard.setTextCalls.last == "Fixed text")
        let saved = try await historyStore.load()
        #expect(saved.count == 1)
    }

    @Test("Failed action leaves error banner")
    func runActionFailure() async throws {
        let (viewModel, executor, clipboard, _, _) = makeViewModel()
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
        let (viewModel, executor, clipboard, _, settingsStore) = makeViewModel()
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
        let (viewModel, _, _, _, settingsStore) = makeViewModel()

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

    @Test("Opening history entry restores result and copies output")
    func openHistoryEntry() {
        let (viewModel, _, clipboard, _, _) = makeViewModel()
        let entry = ClipHistoryEntry(
            actionID: "summarize",
            actionName: "Summarize",
            input: "Long",
            output: "Short"
        )

        viewModel.openHistoryEntry(entry)

        #expect(viewModel.result?.output == "Short")
        #expect(viewModel.screen == .result)
        #expect(clipboard.setTextCalls.last == "Short")
    }
}
