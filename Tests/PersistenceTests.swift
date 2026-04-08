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

    @Test("UserDefaultsSettingsStore persists saved custom actions and actionOrder")
    func savedActionsAndOrderRoundTrip() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults, key: "settings")
        let action = SavedCustomAction(
            id: "saved-test-1",
            name: "Pirate Mode",
            icon: "globe",
            prompt: "Rewrite as a pirate",
            contentTypes: [.text, .code],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        var settings = ClipSettings()
        settings.savedCustomActions = [action]
        settings.actionOrder = ["saved-test-1", "fix-grammar", "summarize"]

        await store.save(settings)
        let loaded = await store.load()

        #expect(loaded.savedCustomActions.count == 1)
        #expect(loaded.savedCustomActions[0].id == "saved-test-1")
        #expect(loaded.savedCustomActions[0].name == "Pirate Mode")
        #expect(loaded.savedCustomActions[0].icon == "globe")
        #expect(loaded.savedCustomActions[0].prompt == "Rewrite as a pirate")
        #expect(loaded.savedCustomActions[0].contentTypes == [.text, .code])
        #expect(loaded.savedCustomActions[0].createdAt == action.createdAt)
        #expect(loaded.actionOrder == ["saved-test-1", "fix-grammar", "summarize"])
    }

    @Test("UserDefaultsSettingsStore returns defaults when store is empty")
    func emptyStoreReturnsDefaults() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults, key: "settings")

        let loaded = await store.load()

        #expect(loaded == ClipSettings())
        #expect(loaded.savedCustomActions.isEmpty)
        #expect(loaded.actionOrder.isEmpty)
    }

    @Test("ClipSettings decodes old JSON without actionOrder (backward-compat)")
    func backwardCompatibilityMissingActionOrder() async {
        let suiteName = "test-\(UUID().uuidString)"
        // Old-format JSON: has savedCustomActions but no actionOrder key
        let oldJSON = """
        {"autoCopy":true,"recentCustomPrompts":["haiku"],"preferredPanel":"history",
         "favoriteActionIDs":["fix-grammar"],"hiddenActionIDs":[],
         "savedCustomActions":[]}
        """.data(using: .utf8)!
        UserDefaults(suiteName: suiteName)!.set(oldJSON, forKey: "settings")

        let store = UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: suiteName)!, key: "settings")
        let loaded = await store.load()

        // All existing fields must survive; missing actionOrder defaults to []
        #expect(loaded.autoCopy == true)
        #expect(loaded.recentCustomPrompts == ["haiku"])
        #expect(loaded.preferredPanel == .history)
        #expect(loaded.favoriteActionIDs == ["fix-grammar"])
        #expect(loaded.actionOrder.isEmpty)
    }
}
