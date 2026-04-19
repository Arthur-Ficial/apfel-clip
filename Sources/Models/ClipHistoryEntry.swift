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

struct ClipboardHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let text: String
    let contentType: ContentType
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        text: String,
        contentType: ContentType,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.contentType = contentType
        self.timestamp = timestamp
    }
}

enum ClipHistorySection: String, CaseIterable, Identifiable, Sendable {
    case transformations
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transformations:
            return "Transformations"
        case .clipboard:
            return "Clipboard"
        }
    }
}

struct ClipResultState: Equatable, Sendable {
    let actionID: String
    let actionName: String
    let input: String
    var output: String
    var copiedToClipboard: Bool
    var createdFromHistory: Bool
    var sourcePrompt: String?   // set for custom-prompt runs; enables "Save as Action" from result
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
    var autoDismiss: Bool = false
}

enum ClipScreen: String, Equatable, Sendable {
    case actions
    case history
    case settings
    case customPrompt
    case result

    var isPrimaryPanel: Bool {
        switch self {
        case .actions, .history, .settings, .result:
            return true
        case .customPrompt:
            return false
        }
    }
}

enum ClipServerState: Equatable, Sendable {
    case starting
    case ready(port: Int)
    case failed(String)
}
