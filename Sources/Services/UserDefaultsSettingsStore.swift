import Foundation

actor UserDefaultsSettingsStore: ClipSettingsStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "apfel-clip.settings") {
        self.defaults = defaults
        self.key = key
    }

    func load() async -> ClipSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(ClipSettings.self, from: data) else {
            return ClipSettings()
        }
        return settings
    }

    func save(_ settings: ClipSettings) async {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
