import Foundation
import Testing
@testable import apfel_clip

@Suite("Update feature")
@MainActor
struct UpdateTests {
    private func makeViewModel() -> PopoverViewModel {
        PopoverViewModel(
            actionExecutor: MockActionExecutor(),
            clipboardService: MockClipboardService(),
            historyStore: MockHistoryStore(),
            settingsStore: MockSettingsStore(),
            launchAtLoginController: MockLaunchAtLoginController()
        )
    }

    @Test("isVersionNewer: patch increment")
    func versionPatch() {
        #expect(PopoverViewModel.isVersionNewer("1.1.6", than: "1.1.5") == true)
        #expect(PopoverViewModel.isVersionNewer("1.1.5", than: "1.1.5") == false)
        #expect(PopoverViewModel.isVersionNewer("1.1.4", than: "1.1.5") == false)
    }

    @Test("isVersionNewer: semver minor beats patch")
    func versionMinor() {
        #expect(PopoverViewModel.isVersionNewer("1.10.0", than: "1.9.0") == true)
        #expect(PopoverViewModel.isVersionNewer("1.9.9", than: "1.10.0") == false)
    }

    @Test("isVersionNewer: major beats all")
    func versionMajor() {
        #expect(PopoverViewModel.isVersionNewer("2.0.0", than: "1.99.99") == true)
    }

    @Test("default update state is idle")
    func defaultIdle() {
        let vm = makeViewModel()
        #expect(vm.updateState == .idle)
    }
}
