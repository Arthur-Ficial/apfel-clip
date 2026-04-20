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

    @Test("FileHistoryStore keeps only the latest 40 entries")
    func historyStoreTruncatesToFortyEntries() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileHistoryStore(url: tempDirectory.appendingPathComponent("history.json"))
        let entries = (0..<45).map { index in
            ClipHistoryEntry(
                actionID: "action-\(index)",
                actionName: "Action \(index)",
                input: "input-\(index)",
                output: "output-\(index)"
            )
        }

        try await store.save(entries)
        let loaded = try await store.load()

        #expect(loaded.count == FileHistoryStore.defaultMaxEntries)
        #expect(loaded.first?.actionID == "action-0")
        #expect(loaded.last?.actionID == "action-39")
    }

    @Test("FileClipboardHistoryStore round-trips entries with limit")
    func clipboardHistoryRoundTrip() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileClipboardHistoryStore(url: tempDirectory.appendingPathComponent("clipboard-history.json"))
        let entries = [
            ClipboardHistoryEntry(text: "first", contentType: .text),
            ClipboardHistoryEntry(text: "second", contentType: .code),
            ClipboardHistoryEntry(text: "third", contentType: .json),
        ]

        try await store.save(entries, limit: 2)
        let loaded = try await store.load(limit: 2)

        #expect(loaded.count == 2)
        #expect(loaded[0].text == "first")
        #expect(loaded[1].contentType == .code)
    }

    @Test("UserDefaultsSettingsStore round-trips settings")
    func settingsRoundTrip() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults, key: "settings")
        let settings = ClipSettings(
            autoCopy: false,
            clipboardHistoryLimit: 12,
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

    @Test("UserDefaultsSettingsStore returns defaults on corrupt data")
    func corruptDataReturnsDefaults() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("not json".data(using: .utf8)!, forKey: "settings")
        let store = UserDefaultsSettingsStore(defaults: defaults, key: "settings")

        let loaded = await store.load()

        #expect(loaded == ClipSettings())
    }

        @Test("ClipSettings clamps clipboard history limit and decodes older payloads")
        func clipboardHistoryLimitCompatibility() throws {
                let decoder = JSONDecoder()

                let legacyData = try #require("""
                {
                    "autoCopy": true,
                    "preferredPanel": "history"
                }
                """.data(using: .utf8))
                let legacySettings = try decoder.decode(ClipSettings.self, from: legacyData)
                #expect(legacySettings.clipboardHistoryLimit == ClipSettings.defaultClipboardHistoryLimit)

                let outOfBoundsData = try #require("""
                {
                    "clipboardHistoryLimit": 999
                }
                """.data(using: .utf8))
                let clampedSettings = try decoder.decode(ClipSettings.self, from: outOfBoundsData)
                #expect(clampedSettings.clipboardHistoryLimit == ClipSettings.clipboardHistoryLimitRange.upperBound)
        }
}
