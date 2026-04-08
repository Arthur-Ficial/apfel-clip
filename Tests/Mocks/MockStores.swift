import Foundation
@testable import apfel_clip

actor MockHistoryStore: ClipHistoryStoring {
    var storedEntries: [ClipHistoryEntry] = []
    var savedSnapshots: [[ClipHistoryEntry]] = []

    func load() async throws -> [ClipHistoryEntry] {
        storedEntries
    }

    func save(_ entries: [ClipHistoryEntry]) async throws {
        storedEntries = entries
        savedSnapshots.append(entries)
    }
}

actor MockSettingsStore: ClipSettingsStoring {
    var storedSettings: ClipSettings = ClipSettings()
    var saveCount = 0

    func load() async -> ClipSettings {
        storedSettings
    }

    func save(_ settings: ClipSettings) async {
        storedSettings = settings
        saveCount += 1
    }
}
