import Foundation

enum ClipLocalAction: String, Codable, Sendable {
    case prettyJSON
}

struct ClipAction: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String
    let systemPrompt: String
    let instruction: String
    let contentTypes: Set<ContentType>
    let localAction: ClipLocalAction?

    init(
        _ id: String,
        name: String,
        icon: String,
        systemPrompt: String,
        instruction: String,
        contentTypes: Set<ContentType>,
        localAction: ClipLocalAction? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.instruction = instruction
        self.contentTypes = contentTypes
        self.localAction = localAction
    }
}

enum ClipActionCatalog {
    private static let rewriterSystem = "You are a text rewriter. Apply the instruction and reply with only the rewritten text. Never add quotes or commentary."
    private static let translatorSystem = "You are a translator. Reply with only the translation."
    private static let explainerSystem = "You are a concise expert explainer."
    private static let codeSystem = "You are a careful code reviewer. Be specific and concise."

    static let all: [ClipAction] = [
        ClipAction(
            "fix-grammar",
            name: "Fix grammar",
            icon: "textformat.abc",
            systemPrompt: rewriterSystem,
            instruction: "Correct all spelling and grammar mistakes:",
            contentTypes: [.text]
        ),
        ClipAction(
            "make-concise",
            name: "Make concise",
            icon: "arrow.down.right.and.arrow.up.left",
            systemPrompt: rewriterSystem,
            instruction: "Rewrite to be shorter and more direct:",
            contentTypes: [.text]
        ),
        ClipAction(
            "make-formal",
            name: "Make formal",
            icon: "briefcase",
            systemPrompt: rewriterSystem,
            instruction: "Rewrite in a formal professional tone and fix all errors:",
            contentTypes: [.text]
        ),
        ClipAction(
            "make-casual",
            name: "Make casual",
            icon: "face.smiling",
            systemPrompt: rewriterSystem,
            instruction: "Rewrite in a casual friendly tone and fix all errors:",
            contentTypes: [.text]
        ),
        ClipAction(
            "summarize",
            name: "Summarize",
            icon: "text.badge.minus",
            systemPrompt: "Summarize in 1-3 precise sentences. Reply with only the summary.",
            instruction: "Summarize:",
            contentTypes: [.text, .code]
        ),
        ClipAction(
            "bullet-points",
            name: "Bullet points",
            icon: "list.bullet",
            systemPrompt: rewriterSystem,
            instruction: "Convert this into concise bullet points, each starting with '- ':",
            contentTypes: [.text]
        ),
        ClipAction(
            "translate-de",
            name: "German",
            icon: "globe",
            systemPrompt: translatorSystem,
            instruction: "Translate to German:",
            contentTypes: [.text]
        ),
        ClipAction(
            "translate-fr",
            name: "French",
            icon: "globe",
            systemPrompt: translatorSystem,
            instruction: "Translate to French:",
            contentTypes: [.text]
        ),
        ClipAction(
            "translate-es",
            name: "Spanish",
            icon: "globe",
            systemPrompt: translatorSystem,
            instruction: "Translate to Spanish:",
            contentTypes: [.text]
        ),
        ClipAction(
            "translate-ja",
            name: "Japanese",
            icon: "globe",
            systemPrompt: translatorSystem,
            instruction: "Translate to Japanese:",
            contentTypes: [.text]
        ),
        ClipAction(
            "explain-code",
            name: "Explain code",
            icon: "questionmark.circle",
            systemPrompt: codeSystem,
            instruction: "Explain what this code does in 2-3 sentences:",
            contentTypes: [.code]
        ),
        ClipAction(
            "find-bugs",
            name: "Find bugs",
            icon: "ladybug",
            systemPrompt: codeSystem,
            instruction: "List any bugs or issues, each on its own line starting with '- ':",
            contentTypes: [.code]
        ),
        ClipAction(
            "add-comments",
            name: "Add comments",
            icon: "text.bubble",
            systemPrompt: "Reply with only the code with comments added. Keep behavior unchanged.",
            instruction: "Add clear inline comments to this code:",
            contentTypes: [.code]
        ),
        ClipAction(
            "simplify-code",
            name: "Simplify",
            icon: "wand.and.rays",
            systemPrompt: rewriterSystem,
            instruction: "Simplify this code while keeping the same behavior:",
            contentTypes: [.code]
        ),
        ClipAction(
            "explain-error",
            name: "Explain error",
            icon: "questionmark.circle",
            systemPrompt: explainerSystem,
            instruction: "Explain this error and suggest a fix:",
            contentTypes: [.error]
        ),
        ClipAction(
            "suggest-fix",
            name: "Suggest fix",
            icon: "wrench",
            systemPrompt: "Reply with only the fix command or code change.",
            instruction: "Give the exact fix for this error:",
            contentTypes: [.error]
        ),
        ClipAction(
            "explain-command",
            name: "Explain command",
            icon: "questionmark.circle",
            systemPrompt: explainerSystem,
            instruction: "Explain what this shell command does:",
            contentTypes: [.shellCommand]
        ),
        ClipAction(
            "make-safer",
            name: "Make safer",
            icon: "shield",
            systemPrompt: "Reply with only a safer version of the command, with brief inline # comments when useful.",
            instruction: "Add safeguards to this shell command:",
            contentTypes: [.shellCommand]
        ),
        ClipAction(
            "explain-json",
            name: "Explain structure",
            icon: "questionmark.circle",
            systemPrompt: explainerSystem,
            instruction: "Explain the structure of this JSON:",
            contentTypes: [.json]
        ),
        ClipAction(
            "pretty-json",
            name: "Pretty format",
            icon: "text.alignleft",
            systemPrompt: "",
            instruction: "",
            contentTypes: [.json],
            localAction: .prettyJSON
        ),
    ]

    static func actions(for contentType: ContentType) -> [ClipAction] {
        all.filter { $0.contentTypes.contains(contentType) }
    }

    static func action(id: String) -> ClipAction? {
        all.first { $0.id == id }
    }
}
