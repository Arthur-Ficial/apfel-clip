import Foundation
import Testing
@testable import apfel_clip

@Suite("Hotkey Settings")
@MainActor
struct HotkeySettingsTests {
    private func makeViewModel() -> (PopoverViewModel, MockSettingsStore) {
        let executor = MockActionExecutor()
        let clipboard = MockClipboardService()
        let historyStore = MockHistoryStore()
        let settingsStore = MockSettingsStore()
        let launchAtLoginController = MockLaunchAtLoginController()
        let viewModel = PopoverViewModel(
            actionExecutor: executor,
            clipboardService: clipboard,
            historyStore: historyStore,
            settingsStore: settingsStore,
            launchAtLoginController: launchAtLoginController
        )
        return (viewModel, settingsStore)
    }

    @Test("Default hotkey display label is Shift+Cmd+V")
    func defaultHotkeyLabel() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.hotkeyDisplayLabel == "\u{21E7}\u{2318}V")
    }

    @Test("updateHotkey persists the new hotkey config")
    func updateHotkeyPersists() async {
        let (viewModel, settingsStore) = makeViewModel()
        let newHotkey = HotkeyConfig(key: "a", modifiers: [.command, .option])
        await viewModel.updateHotkey(newHotkey)
        let saved = await settingsStore.load()
        #expect(saved.hotkey == newHotkey)
        #expect(viewModel.settings.hotkey == newHotkey)
    }

    @Test("hotkeyDisplayLabel reflects updated hotkey")
    func labelUpdatesAfterChange() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.updateHotkey(HotkeyConfig(key: "k", modifiers: [.control, .shift]))
        #expect(viewModel.hotkeyDisplayLabel == "\u{2303}\u{21E7}K")
    }

    @Test("Loaded settings preserve custom hotkey")
    func loadedSettingsPreserveHotkey() async {
        let (viewModel, settingsStore) = makeViewModel()
        var settings = ClipSettings()
        settings.hotkey = HotkeyConfig(key: "j", modifiers: [.command])
        await settingsStore.save(settings)
        await viewModel.loadPersistedState()
        #expect(viewModel.settings.hotkey.key == "j")
        #expect(viewModel.hotkeyDisplayLabel == "\u{2318}J")
    }

    @Test("onHotkeyChanged callback fires when hotkey is updated")
    func onHotkeyChangedCallbackFires() async {
        let (viewModel, _) = makeViewModel()
        var callbackHotkey: HotkeyConfig?
        viewModel.onHotkeyChanged = { config in callbackHotkey = config }
        let newHotkey = HotkeyConfig(key: "b", modifiers: [.command, .shift])
        await viewModel.updateHotkey(newHotkey)
        #expect(callbackHotkey == newHotkey)
    }
}
