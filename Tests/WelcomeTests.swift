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

    // ── checkWelcomeScreenNeeded — first run only ────────────────────────────

    @Test("welcome shows on first run when lastSeenVersion is empty")
    func showsOnFirstRun() async {
        let vm = makeViewModel()
        await vm.loadPersistedState()  // lastSeenVersion stays ""
        vm.checkWelcomeScreenNeeded()
        #expect(vm.isWelcomeVisible == true)
    }

    @Test("welcome hidden after first run when lastSeenVersion is set")
    func hiddenAfterFirstRun() async {
        let store = MockSettingsStore()
        let vm = makeViewModel(settingsStore: store)
        // Any non-empty lastSeenVersion = has been seen before
        var s = ClipSettings()
        s.lastSeenVersion = "1.0.0"
        await store.save(s)
        await vm.loadPersistedState()
        vm.checkWelcomeScreenNeeded()
        #expect(vm.isWelcomeVisible == false)
    }

    @Test("welcome hidden on update (version change doesn't re-trigger)")
    func hiddenOnVersionUpdate() async {
        let store = MockSettingsStore()
        let vm = makeViewModel(settingsStore: store)
        // lastSeenVersion is old version — still hidden (first-run-only logic)
        var s = ClipSettings()
        s.lastSeenVersion = "0.1.0"
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

    // ── debugResetFirstRun ───────────────────────────────────────────────────

    @Test("debugResetFirstRun shows sheet and clears lastSeenVersion")
    func debugReset() async {
        let store = MockSettingsStore()
        let vm = makeViewModel(settingsStore: store)
        // Start as if already dismissed
        var s = ClipSettings()
        s.lastSeenVersion = "99.9.9"
        await store.save(s)
        await vm.loadPersistedState()
        vm.checkWelcomeScreenNeeded()
        #expect(vm.isWelcomeVisible == false)

        await vm.debugResetFirstRun()

        #expect(vm.isWelcomeVisible == true)
        #expect(vm.settings.lastSeenVersion == "")
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
