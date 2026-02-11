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

    var maxPlaceholderIndex: Int {
        var maxIndex = 0
        for command in commands {
            for i in 1...99 {
                if command.contains("{\(i)}") {
                    maxIndex = max(maxIndex, i)
                } else if i > maxIndex + 1 {
                    break
                }
            }
        }
        return maxIndex
    }

    func substituting(arguments: [String]) -> Alias {
        let substitutedCommands = commands.map { command in
            var result = command
            for (index, arg) in arguments.enumerated() {
                result = result.replacingOccurrences(of: "{\(index + 1)}", with: arg)
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

    func substitutingSecrets(_ secrets: [String: String]) -> Alias {
        let substitutedCommands = commands.map { command in
            var result = command
            for (key, value) in secrets {
                result = result.replacingOccurrences(of: "{\(key)}", with: value)
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

    func execute() async {
        switch executionType {
        case .sequential:
            await runCommands(commands.joined(separator: " "))
        case .parallel:
            await runParallelCommands(commands)
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
