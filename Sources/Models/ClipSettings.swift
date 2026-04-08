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
        let strict = "Output ONLY the result. No introduction, no explanation, no commentary, no before/after labels, no quotes, no sign-off."
        return ClipAction(
            id,
            name: name,
            icon: icon,
            systemPrompt: "Apply the user's instruction to the input. \(strict)",
            instruction: prompt,
            contentTypes: contentTypes,
            localAction: nil
        )
    }
}

struct ClipSettings: Codable, Equatable, Sendable {
    var autoCopy: Bool = false
    var recentCustomPrompts: [String] = []
    var preferredPanel: ClipPrimaryPanel = .actions
    var favoriteActionIDs: [String] = []
    var hiddenActionIDs: [String] = []
    var savedCustomActions: [SavedCustomAction] = []
    var actionOrder: [String] = []   // user-defined ordering; empty = default
}

// Custom decoder in extension so the compiler still synthesises memberwise init.
// All fields use decodeIfPresent: new fields added in future app versions will
// never cause a decode failure on existing persisted data.
extension ClipSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoCopy            = try c.decodeIfPresent(Bool.self,                  forKey: .autoCopy)            ?? false
        recentCustomPrompts = try c.decodeIfPresent([String].self,              forKey: .recentCustomPrompts) ?? []
        preferredPanel      = try c.decodeIfPresent(ClipPrimaryPanel.self,      forKey: .preferredPanel)      ?? .actions
        favoriteActionIDs   = try c.decodeIfPresent([String].self,              forKey: .favoriteActionIDs)   ?? []
        hiddenActionIDs     = try c.decodeIfPresent([String].self,              forKey: .hiddenActionIDs)     ?? []
        savedCustomActions  = try c.decodeIfPresent([SavedCustomAction].self,   forKey: .savedCustomActions)  ?? []
        actionOrder         = try c.decodeIfPresent([String].self,              forKey: .actionOrder)         ?? []
    }
}
