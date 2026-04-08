import Foundation

enum ClipPrimaryPanel: String, Codable, CaseIterable, Sendable {
    case actions
    case history
    case settings

    var title: String {
        switch self {
        case .actions:
            return "Actions"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var screen: ClipScreen {
        switch self {
        case .actions:
            return .actions
        case .history:
            return .history
        case .settings:
            return .settings
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
