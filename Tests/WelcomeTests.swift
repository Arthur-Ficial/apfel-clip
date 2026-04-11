import Foundation
import Testing
@testable import apfel_clip

@Suite("Welcome screen")
@MainActor
struct WelcomeTests {
    private func makeViewModel(settingsStore: MockSettingsStore = MockSettingsStore()) -> PopoverViewModel {
        PopoverViewModel(
            actionExecutor: MockActionExecutor(),
            clipboardService: MockClipboardService(),
            historyStore: MockHistoryStore(),
            settingsStore: settingsStore,
            launchAtLoginController: MockLaunchAtLoginController()
        )
    }

    // ── Default settings ─────────────────────────────────────────────────────

    @Test("checkForUpdatesOnLaunch defaults to true")
    func defaultCheckOnLaunch() {
        #expect(ClipSettings().checkForUpdatesOnLaunch == true)
    }

    @Test("lastSeenVersion defaults to empty string")
    func defaultLastSeen() {
        #expect(ClipSettings().lastSeenVersion == "")
    }

    // ── checkWelcomeScreenNeeded ─────────────────────────────────────────────

    @Test("welcome shows when lastSeenVersion differs from currentVersion")
    func showsWhenVersionDiffers() async {
        let vm = makeViewModel()
        await vm.loadPersistedState()  // lastSeenVersion stays ""
        vm.checkWelcomeScreenNeeded()
        // currentVersion is "unknown" in tests (no bundle), lastSeenVersion is "" → different
        #expect(vm.isWelcomeVisible == true)
    }

    @Test("welcome hidden when lastSeenVersion matches currentVersion")
    func hiddenWhenVersionMatches() async {
        let store = MockSettingsStore()
        let vm = makeViewModel(settingsStore: store)
        // Pre-seed lastSeenVersion = currentVersion before loading
        var s = ClipSettings()
        s.lastSeenVersion = vm.currentVersion
        await store.save(s)
        await vm.loadPersistedState()
        vm.checkWelcomeScreenNeeded()
        #expect(vm.isWelcomeVisible == false)
    }

    // ── dismissWelcome ───────────────────────────────────────────────────────

    @Test("dismissWelcome hides overlay and saves lastSeenVersion")
    func dismissPersists() async {
        let store = MockSettingsStore()
        let vm = makeViewModel(settingsStore: store)
        await vm.loadPersistedState()
        vm.checkWelcomeScreenNeeded()
        #expect(vm.isWelcomeVisible == true)

        await vm.dismissWelcome()

        #expect(vm.isWelcomeVisible == false)
        #expect(vm.settings.lastSeenVersion == vm.currentVersion)
        // Verify it was actually saved to the store
        let saved = await store.load()
        #expect(saved.lastSeenVersion == vm.currentVersion)
    }

    // ── showWelcome ──────────────────────────────────────────────────────────

    @Test("showWelcome makes overlay visible")
    func showWelcome() async {
        let vm = makeViewModel()
        await vm.loadPersistedState()
        // Dismiss first so it's hidden
        await vm.dismissWelcome()
        #expect(vm.isWelcomeVisible == false)
        vm.showWelcome()
        #expect(vm.isWelcomeVisible == true)
    }

    // ── checkForUpdateSilentlyOnLaunch ───────────────────────────────────────

    @Test("silent check does nothing when checkForUpdatesOnLaunch is disabled")
    func silentCheckSkipsWhenDisabled() async {
        let vm = makeViewModel()
        await vm.loadPersistedState()
        vm.settings.checkForUpdatesOnLaunch = false
        await vm.checkForUpdateSilentlyOnLaunch()
        #expect(vm.updateState == .idle)
    }

    @Test("silent check never sets error state even when enabled")
    func silentCheckNeverErrors() async {
        let vm = makeViewModel()
        await vm.loadPersistedState()
        vm.settings.checkForUpdatesOnLaunch = true
        await vm.checkForUpdateSilentlyOnLaunch()
        if case .error = vm.updateState {
            Issue.record("Silent launch check must never set error state")
        }
    }
}
