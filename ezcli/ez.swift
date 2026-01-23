import ArgumentParser
import Foundation

private let VERSION = "v1.0.2"

@main
struct Ez: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ez",
        abstract: "Streamlines CLI command execution through aliases.",
        discussion: """
🐘 `ez` simplifies frequent command usage by storing terminal commands with short, memorable aliases.

Aliases are stored in a JSON file (.ez_cli.json) within each directory, allowing for context-specific command sets. Local aliases take precedence when names conflict.

Manage alias storage:
    - Delete .ez_cli.json to clear local aliases.
""",
        version: VERSION,
        subcommands: [Add.self, Remove.self, List.self, InstallCompletions.self, UninstallCompletions.self, ExecuteCommand.self]
    )

    static func main() async throws {
        // Setup signal handlers to forward signals to child processes
        signal(SIGINT) { _ in
            for pid in childPids {
                kill(pid, SIGINT)
            }
        }

        signal(SIGTERM) { _ in
            for pid in childPids {
                kill(pid, SIGTERM)
            }
        }

        signal(SIGQUIT) { _ in
            for pid in childPids {
                kill(pid, SIGQUIT)
            }
        }

        signal(SIGTSTP) { _ in
            for pid in childPids {
                kill(pid, SIGTSTP)
            }
        }

        signal(SIGCONT) { _ in
            for pid in childPids {
                kill(pid, SIGCONT)
            }
        }

        var arguments = CommandLine.arguments

        // Remove the executable name
        let _ = arguments.removeFirst()

        guard let command = arguments.first?.lowercased() else {
            exit(withError: CleanExit.helpRequest(Ez.self))
        }
        arguments.removeFirst()

        switch command {
        case "list":
            List.main(arguments)
        case "add":
            Add.main(arguments)
        case "remove":
            Remove.main(arguments)
        case "install-completions":
            InstallCompletions.main(arguments)
        case "uninstall-completions":
            UninstallCompletions.main(arguments)
        case "help":
            let question = arguments.first?.lowercased()
            switch question {
            case "add":
                exit(withError: CleanExit.helpRequest(Add.self))
            case "remove":
                exit(withError: CleanExit.helpRequest(Remove.self))
            case "list":
                exit(withError: CleanExit.helpRequest(List.self))
            case "install-completions":
                exit(withError: CleanExit.helpRequest(InstallCompletions.self))
            case "uninstall-completions":
                exit(withError: CleanExit.helpRequest(UninstallCompletions.self))
            default:
                exit(withError: CleanExit.helpRequest(Ez.self))
            }
        case "-h", "--help":
            exit(withError: CleanExit.helpRequest(Ez.self))
        case "--version":
            print(VERSION)
            exit(withError: nil)
        default:
            guard let alias = AliasCollection(scope: Scope.local).alias(for: command) else {
                printError("🐘 Unknown alias: \(command.format(bold: true, color: .blue)).")
                exit(withError: nil)
            }

            print("🐘 Executing: \(alias.commandsDescription)".format(bold: true, color: .green))
            await alias.execute()
        }
    }

    // Placeholder for potential options at the top level
    func run() throws {
        // This method will not be called because we handle everything in main()
    }
}
