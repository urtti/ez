import Foundation

struct Alias: Codable {
    let executionType: ExecutionType
    let commands: [String]
    let description: String?

    var commandsDescription: String {
        return switch executionType {
        case .sequential: commands.joined(separator: " ")
        case .parallel: commands.joined(separator: " | ")
        }
    }

    // Recorded as the run history key; " ;; " keeps concurrent commands from reading as a shell pipeline
    var commandTemplate: String {
        return switch executionType {
        case .sequential: commands.joined(separator: " ")
        case .parallel: commands.joined(separator: " ;; ")
        }
    }

    // Only counts placeholders substituting(arguments:) can fill: {1}–{99}, no leading zeros.
    var maxPlaceholderIndex: Int {
        var maxIndex = 0
        for command in commands {
            for match in command.matches(of: /\{([1-9][0-9]?)\}/) {
                maxIndex = max(maxIndex, Int(match.1) ?? 0)
            }
        }
        return maxIndex
    }

    func substituting(arguments: [String]) -> Alias {
        let substitutedCommands = commands.map { command in
            var result = command
            for (index, arg) in arguments.enumerated() {
                result = result.replacingOccurrences(of: "{\(index + 1)}", with: shellEscape(arg))
            }
            return result
        }
        return Alias(executionType: executionType, commands: substitutedCommands, description: description)
    }

    var secretKeys: Set<String> {
        var keys = Set<String>()
        for command in commands {
            var i = command.startIndex
            while i < command.endIndex {
                if command[i] == "{" {
                    let start = command.index(after: i)
                    if let end = command[start...].firstIndex(of: "}") {
                        let placeholder = String(command[start..<end])
                        if placeholder.hasPrefix("EZ_") && placeholder.range(of: "^EZ_[A-Z0-9_]+$", options: .regularExpression) != nil {
                            keys.insert(placeholder)
                        }
                        i = command.index(after: end)
                    } else {
                        i = command.index(after: i)
                    }
                } else {
                    i = command.index(after: i)
                }
            }
        }
        return keys
    }

    // Secrets travel to the child in its environment, never argv, so resolved values stay
    // out of the process table (`ps`). Each {EZ_FOO} becomes "$EZ_FOO" — double-quoted, so
    // zsh expands it without word-splitting or globbing mangling the value.
    func referencingSecretsFromEnvironment(_ keys: Set<String>) -> Alias {
        let substitutedCommands = commands.map { command in
            var result = command
            for key in keys {
                result = result.replacingOccurrences(of: "{\(key)}", with: "\"$\(key)\"")
            }
            return result
        }
        return Alias(executionType: executionType, commands: substitutedCommands, description: description)
    }

    func appending(extraArguments: [String]) -> Alias {
        guard !extraArguments.isEmpty else { return self }
        let escaped = extraArguments.map { shellEscape($0) }.joined(separator: " ")
        var newCommands = commands
        if let last = newCommands.last {
            newCommands[newCommands.count - 1] = last + " " + escaped
        }
        return Alias(executionType: executionType, commands: newCommands, description: description)
    }

    // commandTemplate is the pre-substitution definition, so secrets are never recorded;
    // displayCommands are pre-secret too, so resolved secrets never reach the terminal.
    // secrets are exported into the child's environment, keeping values out of argv.
    // Returns the exit code ez itself should exit with, so `ez test && deploy` behaves.
    func execute(aliasName: String, commandTemplate: String, displayCommands: [String], secrets: [String: String]) async -> Int32 {
        switch executionType {
        case .sequential:
            return await runCommands(commands.joined(separator: " "), aliasName: aliasName, commandTemplate: commandTemplate, secrets: secrets)
        case .parallel:
            return await runParallelCommands(commands, displayCommands: displayCommands, aliasName: aliasName, commandTemplate: commandTemplate, secrets: secrets)
        }
    }
}

private func shellEscape(_ arg: String) -> String {
    if arg.allSatisfy({ $0.isLetter || $0.isNumber || "_-./,:@+".contains($0) }) {
        return arg
    }
    return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

enum ExecutionType: String, Codable {
    case sequential
    case parallel

    var color: FontColor {
        return switch self {
        case .sequential: .blue
        case .parallel: .blue
        }
    }
}
