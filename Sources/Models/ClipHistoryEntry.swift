import Foundation

struct ClipHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let actionID: String
    let actionName: String
    let input: String
    let output: String
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        actionID: String,
        actionName: String,
        input: String,
        output: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.actionID = actionID
        self.actionName = actionName
        self.input = input
        self.output = output
        self.timestamp = timestamp
    }
}

struct ClipResultState: Equatable, Sendable {
    let actionID: String
    let actionName: String
    let input: String
    let output: String
    var copiedToClipboard: Bool
    var createdFromHistory: Bool
}

struct ClipBanner: Equatable, Sendable {
    enum Style: String, Sendable {
        case info
        case success
        case error
    }

    let style: Style
    let title: String
    let detail: String?
}

enum ClipScreen: String, Equatable, Sendable {
    case actions
    case history
    case settings
    case customPrompt
    case result

    var isPrimaryPanel: Bool {
        switch self {
        case .actions, .history, .settings:
            return true
        case .customPrompt, .result:
            return false
        }
    }
}

enum ClipServerState: Equatable, Sendable {
    case starting
    case ready(port: Int)
    case failed(String)
}
