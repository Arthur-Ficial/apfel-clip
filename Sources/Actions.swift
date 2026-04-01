// ============================================================================
// Actions.swift - Action definitions
// The on-device model works best with:
// - System prompt: establish role + "reply with ONLY the result"
// - User message: instruction + text together
// ============================================================================

import Foundation

struct ClipAction: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    /// System prompt - establishes role.
    let systemPrompt: String
    /// Instruction prepended to the clipboard text in the user message.
    let instruction: String
    let contentTypes: Set<ContentType>
    /// If true, runs locally without AI.
    let isLocal: Bool

    init(
        _ id: String,
        name: String,
        icon: String,
        system: String,
        instruction: String,
        types: Set<ContentType>,
        isLocal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = system
        self.instruction = instruction
        self.contentTypes = types
        self.isLocal = isLocal
    }
}

// System prompts by category
private let rewriterSystem = "You are a text rewriter. When the user gives you text with an instruction, you apply the instruction and reply with ONLY the rewritten text. Never ask for clarification. Never add quotes."
private let translatorSystem = "You are a translator. Reply with ONLY the translation. Nothing else."
private let explainerSystem = "You are an expert. Explain clearly and concisely."
private let codeSystem = "You are a code expert. Be specific and concise."

enum Actions {
    // MARK: - Text actions

    static let fixGrammar = ClipAction(
        "fix-grammar",
        name: "Fix grammar",
        icon: "textformat.abc",
        system: rewriterSystem,
        instruction: "Correct all spelling and grammar errors:",
        types: [.text]
    )

    static let makeConcise = ClipAction(
        "make-concise",
        name: "Make concise",
        icon: "arrow.down.right.and.arrow.up.left",
        system: rewriterSystem,
        instruction: "Rewrite to be shorter and more direct, cut filler words:",
        types: [.text]
    )

    static let makeFormal = ClipAction(
        "make-formal",
        name: "Make formal",
        icon: "briefcase",
        system: rewriterSystem,
        instruction: "Rewrite in a formal professional tone and fix all errors:",
        types: [.text]
    )

    static let makeCasual = ClipAction(
        "make-casual",
        name: "Make casual",
        icon: "face.smiling",
        system: rewriterSystem,
        instruction: "Rewrite in a casual friendly tone and fix all errors:",
        types: [.text]
    )

    static let summarize = ClipAction(
        "summarize",
        name: "Summarize",
        icon: "text.badge.minus",
        system: "Summarize in 1-3 sentences. Be specific, not generic.",
        instruction: "Summarize:",
        types: [.text, .code]
    )

    static let bulletPoints = ClipAction(
        "bullet-points",
        name: "Bullet points",
        icon: "list.bullet",
        system: rewriterSystem,
        instruction: "Convert into concise bullet points, each starting with '- ':",
        types: [.text]
    )

    // MARK: - Translation

    static let translateGerman = ClipAction(
        "translate-de", name: "German", icon: "globe",
        system: translatorSystem, instruction: "Translate to German:", types: [.text]
    )
    static let translateFrench = ClipAction(
        "translate-fr", name: "French", icon: "globe",
        system: translatorSystem, instruction: "Translate to French:", types: [.text]
    )
    static let translateSpanish = ClipAction(
        "translate-es", name: "Spanish", icon: "globe",
        system: translatorSystem, instruction: "Translate to Spanish:", types: [.text]
    )
    static let translateJapanese = ClipAction(
        "translate-ja", name: "Japanese", icon: "globe",
        system: translatorSystem, instruction: "Translate to Japanese:", types: [.text]
    )

    // MARK: - Code

    static let explainCode = ClipAction(
        "explain-code", name: "Explain code", icon: "questionmark.circle",
        system: codeSystem, instruction: "Explain what this code does in 2-3 sentences:", types: [.code]
    )
    static let findBugs = ClipAction(
        "find-bugs", name: "Find bugs", icon: "ladybug",
        system: codeSystem, instruction: "List any bugs or issues, each on its own line starting with '- ':", types: [.code]
    )
    static let addComments = ClipAction(
        "add-comments", name: "Add comments", icon: "text.bubble",
        system: "Reply with ONLY the code with comments added. Do not change the code.",
        instruction: "Add clear inline comments to this code:", types: [.code]
    )
    static let simplifyCode = ClipAction(
        "simplify-code", name: "Simplify", icon: "wand.and.rays",
        system: rewriterSystem, instruction: "Simplify this code, keep the same behavior:", types: [.code]
    )

    // MARK: - Error

    static let explainError = ClipAction(
        "explain-error", name: "Explain error", icon: "questionmark.circle",
        system: explainerSystem, instruction: "Explain this error and suggest a fix:", types: [.error]
    )
    static let suggestFix = ClipAction(
        "suggest-fix", name: "Suggest fix", icon: "wrench",
        system: "Reply with ONLY the fix command or code change.",
        instruction: "Give the exact fix for this error:", types: [.error]
    )

    // MARK: - Shell

    static let explainCommand = ClipAction(
        "explain-command", name: "Explain command", icon: "questionmark.circle",
        system: explainerSystem, instruction: "Explain what this shell command does:", types: [.shellCommand]
    )
    static let makeSafer = ClipAction(
        "make-safer", name: "Make safer", icon: "shield",
        system: "Reply with ONLY the improved command with brief # comments.",
        instruction: "Add safeguards to this command:", types: [.shellCommand]
    )

    // MARK: - JSON

    static let explainJSON = ClipAction(
        "explain-json", name: "Explain structure", icon: "questionmark.circle",
        system: explainerSystem, instruction: "Explain the structure of this JSON:", types: [.json]
    )
    static let prettyJSON = ClipAction(
        "pretty-json", name: "Pretty format", icon: "text.alignleft",
        system: "", instruction: "", types: [.json], isLocal: true
    )

    // MARK: - Grouped

    static let textActions: [ClipAction] = [
        fixGrammar, makeConcise, makeFormal, makeCasual,
        summarize, bulletPoints,
        translateGerman, translateFrench, translateSpanish, translateJapanese,
    ]
    static let codeActions: [ClipAction] = [explainCode, findBugs, addComments, simplifyCode, summarize]
    static let errorActions: [ClipAction] = [explainError, suggestFix]
    static let shellActions: [ClipAction] = [explainCommand, makeSafer]
    static let jsonActions: [ClipAction] = [explainJSON, prettyJSON]

    static func forType(_ type: ContentType) -> [ClipAction] {
        switch type {
        case .text: return textActions
        case .code: return codeActions
        case .error: return errorActions
        case .shellCommand: return shellActions
        case .json: return jsonActions
        }
    }
}
