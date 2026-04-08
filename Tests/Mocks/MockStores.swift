import Foundation
@testable import apfel_clip

actor MockHistoryStore: ClipHistoryStoring {
    var storedEntries: [ClipHistoryEntry] = []

    func load() async throws -> [ClipHistoryEntry] { storedEntries }
    func save(_ entries: [ClipHistoryEntry]) async throws { storedEntries = entries }
}

actor MockSettingsStore: ClipSettingsStoring {
    var storedSettings: ClipSettings = ClipSettings()

    func load() async -> ClipSettings { storedSettings }
    func save(_ settings: ClipSettings) async { storedSettings = settings }
}
