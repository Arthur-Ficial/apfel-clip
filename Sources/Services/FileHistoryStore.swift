import Foundation

actor FileHistoryStore: ClipHistoryStoring {
    static let defaultMaxEntries = 40

    private let url: URL
    private let maxEntries: Int

    init(url: URL = FileHistoryStore.defaultURL(), maxEntries: Int = FileHistoryStore.defaultMaxEntries) {
        self.url = url
        self.maxEntries = maxEntries
    }

    func load() async throws -> [ClipHistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ClipHistoryEntry].self, from: data)
        return Array(decoded.prefix(maxEntries))
    }

    func save(_ entries: [ClipHistoryEntry]) async throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let clipped = Array(entries.prefix(maxEntries))
        let data = try JSONEncoder.prettyPrinted.encode(clipped)
        try data.write(to: url, options: .atomic)
    }

    static func defaultURL() -> URL {
        applicationSupportDirectory(appName: "apfel-clip")
            .appendingPathComponent("history.json")
    }
}
