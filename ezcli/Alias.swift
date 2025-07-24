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
