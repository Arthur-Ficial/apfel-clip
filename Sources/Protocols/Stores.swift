import Foundation

protocol ClipHistoryStoring: Sendable {
    func load() async throws -> [ClipHistoryEntry]
    func save(_ entries: [ClipHistoryEntry]) async throws
}

protocol ClipboardHistoryStoring: Sendable {
    func load(limit: Int) async throws -> [ClipboardHistoryEntry]
    func save(_ entries: [ClipboardHistoryEntry], limit: Int) async throws
}

protocol ClipSettingsStoring: Sendable {
    func load() async -> ClipSettings
    func save(_ settings: ClipSettings) async
}

@MainActor
protocol PopoverPresenting: AnyObject {
    func showPopover()
    func hidePopover()
}
