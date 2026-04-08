import Foundation

actor UserDefaultsSettingsStore: ClipSettingsStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "apfel-clip.settings") {
        self.defaults = defaults
        self.key = key
    }

    func load() async -> ClipSettings {
        guard let data = defaults.data(forKey: key) else {
            return ClipSettings()
        }
        do {
            return try JSONDecoder().decode(ClipSettings.self, from: data)
        } catch {
            // Log decode failure so data-loss bugs are visible in Console.app
            print("[apfel-clip] ⚠️ Failed to decode ClipSettings — reverting to defaults. Error: \(error)")
            return ClipSettings()
        }
    }

    func save(_ settings: ClipSettings) async {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        // Explicit synchronize ensures the write reaches disk even under abnormal
        // termination (crash, force-quit). Deprecated but still reliable on macOS.
        defaults.synchronize()
    }
}
