import Foundation

enum ContentType: String, CaseIterable, Codable, Hashable, Sendable {
    case code = "Code"
    case error = "Error"
    case shellCommand = "Command"
    case json = "JSON"
    case text = "Text"

    var icon: String {
        switch self {
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .error:
            return "exclamationmark.triangle"
        case .shellCommand:
            return "terminal"
        case .json:
            return "curlybraces"
        case .text:
            return "text.alignleft"
        }
    }
}

enum ContentDetector {
    static func detect(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && isValidJSON(trimmed) {
            return .json
        }

        let errorPatterns = [
            "error:", "Error:", "ERROR:", "exception", "Exception",
            "traceback", "Traceback", "FATAL", "fatal:",
            "panic:", "PANIC:", "failed:", "Failed:",
            "Cannot ", "cannot ", "Could not", "could not",
            "No such file", "Permission denied", "Segmentation fault",
            "undefined reference", "unresolved", "compilation error",
        ]
        if errorPatterns.contains(where: { trimmed.contains($0) }) {
            return .error
        }

        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let commandLine = firstLine.trimmingCharacters(in: .whitespaces)
        if commandLine.hasPrefix("$ ") || commandLine.hasPrefix("# ") {
            return .shellCommand
        }

        let shellCommands = [
            "ls ", "cd ", "grep ", "curl ", "git ", "docker ", "brew ",
            "npm ", "pip ", "cargo ", "make ", "sudo ", "ssh ", "scp ",
            "cat ", "echo ", "find ", "awk ", "sed ", "sort ", "tar ",
            "chmod ", "chown ", "mkdir ", "rm ", "cp ", "mv ", "wget ",
            "python ", "python3 ", "node ", "swift ", "go ", "rustc ",
        ]
        if shellCommands.contains(where: { commandLine.hasPrefix($0) }) && !trimmed.contains("\n\n") {
            return .shellCommand
        }

        let codePatterns = [
            "func ", "def ", "class ", "import ", "from ", "const ",
            "let ", "var ", "fn ", "pub ", "struct ", "enum ",
            "interface ", "type ", "package ", "module ", "use ",
            "return ", "if (", "for (", "while (", "switch ",
            "try {", "catch ", "throws ", "async ", "await ",
            "=> ", "-> ", "// ", "/* ", "/// ", "#include ",
            "print(", "console.log(", "System.out", "fmt.Print",
        ]
        var score = codePatterns.reduce(into: 0) { partial, pattern in
            if trimmed.contains(pattern) {
                partial += 1
            }
        }

        let lines = trimmed.components(separatedBy: .newlines)
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        if indentedLines.count > max(1, lines.count / 3) {
            score += 2
        }
        if trimmed.contains("{") && trimmed.contains("}") {
            score += 1
        }

        return score >= 3 ? .code : .text
    }

    private static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
