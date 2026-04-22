import AppKit
import Foundation

enum ClipPrimaryPanel: String, Codable, CaseIterable, Sendable {
    case actions
    case history

    var title: String {
        switch self {
        case .actions: return "Action"
        case .history: return "History"
        }
    }

    var screen: ClipScreen {
        switch self {
        case .actions: return .actions
        case .history: return .history
        }
    }
}

struct SavedCustomAction: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var name: String
    var icon: String
    var prompt: String
    var contentTypes: Set<ContentType>
    var createdAt: Date
}

extension SavedCustomAction {
    func asClipAction() -> ClipAction {
        ClipAction(
            id,
            name: name,
            icon: icon,
            systemPrompt: "Apply the user's instruction to the input. \(ClipActionCatalog.strict)",
            instruction: prompt,
            contentTypes: contentTypes,
            localAction: nil
        )
    }
}

struct HotkeyModifier: OptionSet, Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt

    static let command = HotkeyModifier(rawValue: 1 << 0)
    static let shift   = HotkeyModifier(rawValue: 1 << 1)
    static let option  = HotkeyModifier(rawValue: 1 << 2)
    static let control = HotkeyModifier(rawValue: 1 << 3)
}

struct HotkeyConfig: Codable, Equatable, Hashable, Sendable {
    var key: String
    var modifiers: HotkeyModifier

    init(key: String = "v", modifiers: HotkeyModifier = [.command, .shift]) {
        self.key = key
        self.modifiers = modifiers
    }

    var displayLabel: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option)  { parts.append("\u{2325}") }
        if modifiers.contains(.shift)   { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }
        parts.append(key.uppercased())
        return parts.joined()
    }

    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        if modifiers.contains(.option)  { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }

    static func from(event: NSEvent) -> HotkeyConfig? {
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              !chars.isEmpty else { return nil }
        var mods: HotkeyModifier = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.shift)   { mods.insert(.shift) }
        if flags.contains(.option)  { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        guard !mods.isEmpty else { return nil }
        return HotkeyConfig(key: chars, modifiers: mods)
    }
}

struct ClipSettings: Codable, Equatable, Sendable {
    static let clipboardHistoryLimitRange = 1...40
    static let defaultClipboardHistoryLimit = 40

    var hotkey: HotkeyConfig = HotkeyConfig()
    var autoCopy: Bool = false
    var clipboardHistoryLimit: Int = ClipSettings.defaultClipboardHistoryLimit
    var ignoredClipboardSourceBundleIDs: [String] = []
    var launchAtLoginEnabled: Bool = true
    var launchAtLoginPromptShown: Bool = false
    var recentCustomPrompts: [String] = []
    var preferredPanel: ClipPrimaryPanel = .actions
    var favoriteActionIDs: [String] = []
    var hiddenActionIDs: [String] = []
    var savedCustomActions: [SavedCustomAction] = []
    var actionOrder: [String] = []
    var checkForUpdatesOnLaunch: Bool = true
    var lastSeenVersion: String = ""

    init(
        hotkey: HotkeyConfig = HotkeyConfig(),
        autoCopy: Bool = false,
        clipboardHistoryLimit: Int = ClipSettings.defaultClipboardHistoryLimit,
        ignoredClipboardSourceBundleIDs: [String] = [],
        launchAtLoginEnabled: Bool = true,
        launchAtLoginPromptShown: Bool = false,
        recentCustomPrompts: [String] = [],
        preferredPanel: ClipPrimaryPanel = .actions,
        favoriteActionIDs: [String] = [],
        hiddenActionIDs: [String] = [],
        savedCustomActions: [SavedCustomAction] = [],
        actionOrder: [String] = [],
        checkForUpdatesOnLaunch: Bool = true,
        lastSeenVersion: String = ""
    ) {
        self.hotkey = hotkey
        self.autoCopy = autoCopy
        self.clipboardHistoryLimit = ClipSettings.clampClipboardHistoryLimit(clipboardHistoryLimit)
        self.ignoredClipboardSourceBundleIDs = ClipSettings.sanitizeBundleIdentifiers(ignoredClipboardSourceBundleIDs)
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.launchAtLoginPromptShown = launchAtLoginPromptShown
        self.recentCustomPrompts = recentCustomPrompts
        self.preferredPanel = preferredPanel
        self.favoriteActionIDs = favoriteActionIDs
        self.hiddenActionIDs = hiddenActionIDs
        self.savedCustomActions = savedCustomActions
        self.actionOrder = actionOrder
        self.checkForUpdatesOnLaunch = checkForUpdatesOnLaunch
        self.lastSeenVersion = lastSeenVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? HotkeyConfig()
        autoCopy = try container.decodeIfPresent(Bool.self, forKey: .autoCopy) ?? false
        let decodedClipboardHistoryLimit = try container.decodeIfPresent(Int.self, forKey: .clipboardHistoryLimit)
        clipboardHistoryLimit = ClipSettings.clampClipboardHistoryLimit(
            decodedClipboardHistoryLimit ?? ClipSettings.defaultClipboardHistoryLimit
        )
        ignoredClipboardSourceBundleIDs = ClipSettings.sanitizeBundleIdentifiers(
            try container.decodeIfPresent([String].self, forKey: .ignoredClipboardSourceBundleIDs) ?? []
        )
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? true
        launchAtLoginPromptShown = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginPromptShown) ?? false
        recentCustomPrompts = try container.decodeIfPresent([String].self, forKey: .recentCustomPrompts) ?? []
        preferredPanel = try container.decodeIfPresent(ClipPrimaryPanel.self, forKey: .preferredPanel) ?? .actions
        favoriteActionIDs = try container.decodeIfPresent([String].self, forKey: .favoriteActionIDs) ?? []
        hiddenActionIDs = try container.decodeIfPresent([String].self, forKey: .hiddenActionIDs) ?? []
        savedCustomActions = try container.decodeIfPresent([SavedCustomAction].self, forKey: .savedCustomActions) ?? []
        actionOrder = try container.decodeIfPresent([String].self, forKey: .actionOrder) ?? []
        checkForUpdatesOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? true
        lastSeenVersion = try container.decodeIfPresent(String.self, forKey: .lastSeenVersion) ?? ""
    }

    static func clampClipboardHistoryLimit(_ value: Int) -> Int {
        min(max(value, clipboardHistoryLimitRange.lowerBound), clipboardHistoryLimitRange.upperBound)
    }

    static func sanitizeBundleIdentifiers(_ bundleIDs: [String]) -> [String] {
        var deduped: [String] = []
        for bundleID in bundleIDs.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !bundleID.isEmpty {
            if !deduped.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) {
                deduped.append(bundleID)
            }
        }
        return deduped.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
