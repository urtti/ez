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

    func execute() async {
        switch executionType {
        case .sequential:
            await runCommands(commands.joined(separator: " "))
        case .parallel:
            await runParallelCommands(commands)
        }
    }
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
