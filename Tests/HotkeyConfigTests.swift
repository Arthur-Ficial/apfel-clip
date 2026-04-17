import Foundation
import Testing
@testable import apfel_clip

@Suite("HotkeyConfig")
struct HotkeyConfigTests {

    @Test("Default hotkey is Cmd+Shift+V")
    func defaultHotkey() {
        let config = HotkeyConfig()
        #expect(config.key == "v")
        #expect(config.modifiers == [.command, .shift])
    }

    @Test("Display label for default hotkey")
    func defaultDisplayLabel() {
        let config = HotkeyConfig()
        #expect(config.displayLabel == "\u{21E7}\u{2318}V")
    }

    @Test("Display label for Cmd+Opt+A")
    func customDisplayLabel() {
        let config = HotkeyConfig(key: "a", modifiers: [.command, .option])
        #expect(config.displayLabel == "\u{2325}\u{2318}A")
    }

    @Test("Display label for Ctrl+Shift+K")
    func ctrlShiftDisplayLabel() {
        let config = HotkeyConfig(key: "k", modifiers: [.control, .shift])
        #expect(config.displayLabel == "\u{2303}\u{21E7}K")
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = HotkeyConfig(key: "j", modifiers: [.command, .option, .shift])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test("ClipSettings default includes default hotkey")
    func settingsDefaultHotkey() {
        let settings = ClipSettings()
        #expect(settings.hotkey == HotkeyConfig())
    }

    @Test("ClipSettings with custom hotkey round-trips through JSON")
    func settingsHotkeyRoundTrip() throws {
        var settings = ClipSettings()
        settings.hotkey = HotkeyConfig(key: "b", modifiers: [.command, .control])
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClipSettings.self, from: data)
        #expect(decoded.hotkey.key == "b")
        #expect(decoded.hotkey.modifiers == [.command, .control])
    }

    @Test("Decoding ClipSettings without hotkey field uses default")
    func backwardsCompatibility() throws {
        let json = """
        {"autoCopy":true,"launchAtLoginEnabled":false,"launchAtLoginPromptShown":true,
         "recentCustomPrompts":[],"preferredPanel":"actions","favoriteActionIDs":[],
         "hiddenActionIDs":[],"savedCustomActions":[],"actionOrder":[],
         "checkForUpdatesOnLaunch":true,"lastSeenVersion":"0.4.1"}
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ClipSettings.self, from: data)
        #expect(settings.hotkey == HotkeyConfig())
        #expect(settings.autoCopy == true)
    }
}
