import ArgumentParser
import Foundation

private let VERSION = "v0.7.6"

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
        subcommands: [Add.self, Remove.self, List.self, ExecuteCommand.self]
    )

    static func main() async throws {
        // Setup signal handler for SIGINT
        signal(SIGINT) { _ in
            for childProcess in childProcesses {
                print("Interrupting subprocess \(childProcess.key)...")
                childProcess.value.interrupt()
            }
        }

        signal(SIGTERM) { _ in
            for childProcess in childProcesses {
                print("Terminating subprocess \(childProcess.key)...")
                childProcess.value.terminate()
            }
        }

        signal(SIGQUIT) { _ in
            for childProcess in childProcesses {
                print("Quitting subprocess \(childProcess.key)...")
                childProcess.value.terminate()
            }
        }

        signal(SIGKILL) { _ in
            for childProcess in childProcesses {
                print("Killing subprocess \(childProcess.key)...")
                childProcess.value.terminate()
            }
        }

        signal(SIGSTOP) { _ in
            for childProcess in childProcesses {
                print("Stopping subprocess \(childProcess.key)...")
                childProcess.value.suspend()
            }
        }

        signal(SIGCONT) { _ in
            for childProcess in childProcesses {
                print("Continuing subprocess \(childProcess.key)...")
                childProcess.value.resume()
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
        case "help":
            let question = arguments.first?.lowercased()
            switch question {
            case "add":
                exit(withError: CleanExit.helpRequest(Add.self))
            case "remove":
                exit(withError: CleanExit.helpRequest(Remove.self))
            case "list":
                exit(withError: CleanExit.helpRequest(List.self))
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
