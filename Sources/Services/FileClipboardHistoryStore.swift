import Foundation

actor FileClipboardHistoryStore: ClipboardHistoryStoring {
    private let url: URL

    init(url: URL = FileClipboardHistoryStore.defaultURL()) {
        self.url = url
    }

    func load(limit: Int) async throws -> [ClipboardHistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ClipboardHistoryEntry].self, from: data)
        return Array(decoded.prefix(limit))
    }

    func save(_ entries: [ClipboardHistoryEntry], limit: Int) async throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let clipped = Array(entries.prefix(limit))
        let data = try JSONEncoder.prettyPrinted.encode(clipped)
        try data.write(to: url, options: .atomic)
    }

    static func defaultURL() -> URL {
        applicationSupportDirectory(appName: "apfel-clip")
            .appendingPathComponent("clipboard-history.json")
    }
}