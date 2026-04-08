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

struct ClipSettings: Codable, Equatable, Sendable {
    var autoCopy: Bool = false
    var recentCustomPrompts: [String] = []
    var preferredPanel: ClipPrimaryPanel = .actions
    var favoriteActionIDs: [String] = []
    var hiddenActionIDs: [String] = []
    var savedCustomActions: [SavedCustomAction] = []
    var actionOrder: [String] = []
}
