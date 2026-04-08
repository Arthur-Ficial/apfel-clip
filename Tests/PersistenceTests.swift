import Foundation
import Testing
@testable import apfel_clip

@Suite("Persistence")
struct PersistenceTests {
    @Test("FileHistoryStore round-trips entries")
    func historyRoundTrip() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileHistoryStore(url: tempDirectory.appendingPathComponent("history.json"))
        let entries = [
            ClipHistoryEntry(actionID: "fix-grammar", actionName: "Fix grammar", input: "teh", output: "the"),
            ClipHistoryEntry(actionID: "summarize", actionName: "Summarize", input: "Long text", output: "Short"),
        ]

        try await store.save(entries)
        let loaded = try await store.load()

        #expect(loaded.count == 2)
        #expect(loaded[0].actionID == "fix-grammar")
        #expect(loaded[1].output == "Short")
    }

    @Test("UserDefaultsSettingsStore round-trips settings")
    func settingsRoundTrip() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults, key: "settings")
        let settings = ClipSettings(
            autoCopy: false,
            recentCustomPrompts: ["Rewrite as haiku"],
            preferredPanel: .history
        )

        await store.save(settings)
        let loaded = await store.load()

        #expect(loaded == settings)
    }
}
