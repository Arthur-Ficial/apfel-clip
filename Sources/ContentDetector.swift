// ============================================================================
// ContentDetector.swift - Heuristic content type classification
// ============================================================================

import Foundation

enum ContentType: String, Sendable {
    case code = "Code"
    case error = "Error"
    case shellCommand = "Command"
    case json = "JSON"
    case text = "Text"

    var icon: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .error: return "exclamationmark.triangle"
        case .shellCommand: return "terminal"
        case .json: return "curlybraces"
        case .text: return "text.alignleft"
        }
    }
}

enum ContentDetector {
    static func detect(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // JSON: starts with { or [
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && isValidJSON(trimmed) {
            return .json
        }

        // Error patterns
        let errorPatterns = [
            "error:", "Error:", "ERROR:", "exception", "Exception",
            "traceback", "Traceback", "FATAL", "fatal:",
            "panic:", "PANIC:", "failed:", "Failed:",
            "Cannot ", "cannot ", "Could not", "could not",
            "No such file", "Permission denied", "Segmentation fault",
            "undefined reference", "unresolved", "compilation error"
        ]
        for pattern in errorPatterns {
            if trimmed.contains(pattern) {
                return .error
            }
        }

        // Shell command: starts with $ or common commands
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let cmdLine = firstLine.trimmingCharacters(in: .whitespaces)
        if cmdLine.hasPrefix("$ ") || cmdLine.hasPrefix("# ") {
            return .shellCommand
        }
        let shellCommands = [
            "ls ", "cd ", "grep ", "curl ", "git ", "docker ", "brew ",
            "npm ", "pip ", "cargo ", "make ", "sudo ", "ssh ", "scp ",
            "cat ", "echo ", "find ", "awk ", "sed ", "sort ", "tar ",
            "chmod ", "chown ", "mkdir ", "rm ", "cp ", "mv ", "wget ",
            "python ", "python3 ", "node ", "swift ", "go ", "rustc "
        ]
        for cmd in shellCommands {
            if cmdLine.hasPrefix(cmd) && !trimmed.contains("\n\n") {
                return .shellCommand
            }
        }

        // Code patterns
        let codePatterns = [
            "func ", "def ", "class ", "import ", "from ", "const ",
            "let ", "var ", "fn ", "pub ", "struct ", "enum ",
            "interface ", "type ", "package ", "module ", "use ",
            "return ", "if (", "for (", "while (", "switch ",
            "try {", "catch ", "throws ", "async ", "await ",
            "=> ", "-> ", "// ", "/* ", "/// ", "# ", "print(",
            "console.log(", "System.out", "fmt.Print",
        ]
        var codeScore = 0
        for pattern in codePatterns {
            if trimmed.contains(pattern) { codeScore += 1 }
        }
        // Indentation patterns (4+ spaces or tabs at start of lines)
        let lines = trimmed.components(separatedBy: .newlines)
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        if indentedLines.count > lines.count / 3 { codeScore += 2 }
        // Braces
        if trimmed.contains("{") && trimmed.contains("}") { codeScore += 1 }

        if codeScore >= 3 {
            return .code
        }

        return .text
    }

    private static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
