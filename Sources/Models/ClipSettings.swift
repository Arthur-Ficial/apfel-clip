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

struct ClipSettings: Codable, Equatable, Sendable {
    var autoCopy: Bool = false
    var recentCustomPrompts: [String] = []
    var preferredPanel: ClipPrimaryPanel = .actions
    var favoriteActionIDs: [String] = []
    var hiddenActionIDs: [String] = []
}
