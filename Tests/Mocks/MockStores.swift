import Foundation
@testable import apfel_clip

actor MockHistoryStore: ClipHistoryStoring {
    var storedEntries: [ClipHistoryEntry] = []

    func load() async throws -> [ClipHistoryEntry] { storedEntries }
    func save(_ entries: [ClipHistoryEntry]) async throws { storedEntries = entries }
}

actor MockClipboardHistoryStore: ClipboardHistoryStoring {
    var storedEntries: [ClipboardHistoryEntry] = []

    func load(limit: Int) async throws -> [ClipboardHistoryEntry] {
        Array(storedEntries.prefix(limit))
    }

    func save(_ entries: [ClipboardHistoryEntry], limit: Int) async throws {
        storedEntries = Array(entries.prefix(limit))
    }
}

actor MockSettingsStore: ClipSettingsStoring {
    var storedSettings: ClipSettings = ClipSettings()

    func load() async -> ClipSettings { storedSettings }
    func save(_ settings: ClipSettings) async { storedSettings = settings }
}
