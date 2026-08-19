import ArgumentParser
import Foundation

private let VERSION = "1.3.0"

@main
struct Ez: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ez",
        abstract: "Streamlines CLI command execution through aliases.",
        discussion: """
🐘 `ez` simplifies frequent command usage by storing terminal commands with short, memorable aliases.

Aliases are stored in a JSON file (.ez_cli.json) within each directory, allowing for context-specific command sets. Local aliases take precedence when names conflict.

Parametrized aliases:
    Use {1}, {2}, ... {n} as placeholders in commands. They are replaced with arguments at runtime.
    Example: ez add greet "echo Hello {1}" → ez greet World → echo Hello World

Manage alias storage:
    - Delete .ez_cli.json to clear local aliases.
""",
        version: VERSION,
        subcommands: [Add.self, Remove.self, List.self, Stats.self, AddSecret.self, RemoveSecret.self, InstallCompletions.self, UninstallCompletions.self, ExecuteCommand.self]
    )

    static func main() async {
        // Setup signal handlers to forward signals to child processes. The PID table must
        // exist before any handler can fire — see initializeChildPidTable.
        initializeChildPidTable()
        for sig in [SIGINT, SIGTERM, SIGQUIT, SIGTSTP, SIGCONT] {
            signal(sig) { received in
                forwardSignalToChildren(received)
            }
        }

        var arguments = CommandLine.arguments

        // Remove the executable name
        let _ = arguments.removeFirst()

        guard let command = arguments.first?.lowercased() else {
            exit(withError: CleanExit.helpRequest(Ez.self))
        }
        arguments.removeFirst()

        // An alias stored under a reserved name (e.g. created before that keyword shipped)
        // can never run — the subcommand always wins. Say so instead of hiding it forever.
        if PROTECTED_KEYWORDS.contains(command), AliasCollection(scope: Scope.local).alias(for: command) != nil {
            fputs("🐘 Note: an alias named '\(command)' exists in this directory but is shadowed by the built-in '\(command)' command and can never run. Remove it with 'ez remove \(command)', or add it under a different name.\n", stderr)
        }

        switch command {
        case "list":
            List.main(arguments)
        case "add":
            Add.main(arguments)
        case "remove":
            Remove.main(arguments)
        case "stats":
            await Stats.main(arguments)
        case "add-secret":
            AddSecret.main(arguments)
        case "remove-secret":
            RemoveSecret.main(arguments)
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
            case "stats":
                exit(withError: CleanExit.helpRequest(Stats.self))
            case "add-secret":
                exit(withError: CleanExit.helpRequest(AddSecret.self))
            case "remove-secret":
                exit(withError: CleanExit.helpRequest(RemoveSecret.self))
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
                Foundation.exit(1)
            }

            let expectedArgs = alias.maxPlaceholderIndex
            if expectedArgs > 0 && arguments.count < expectedArgs {
                let placeholders = (1...expectedArgs).map { "<arg\($0)>" }.joined(separator: " ")
                printError("🐘 Expected \(expectedArgs) argument(s): ez \(command) \(placeholders)")
                Foundation.exit(1)
            }

            // First expectedArgs fill placeholders; the rest are appended, so no argument is used twice
            var resolvedAlias = expectedArgs > 0 ? alias.substituting(arguments: Array(arguments.prefix(expectedArgs))) : alias
            let extraArgs = Array(arguments.dropFirst(expectedArgs))
            resolvedAlias = resolvedAlias.appending(extraArguments: extraArgs)

            print("🐘 Executing: \(resolvedAlias.commandsDescription)".format(bold: true, color: .green))

            // Resolve secrets from keychain (after printing, so secrets never appear in output).
            // Values go to the child via its environment, never argv, so they stay out of `ps`.
            let displayCommands = resolvedAlias.commands
            let keys = resolvedAlias.secretKeys
            var secrets: [String: String] = [:]
            if !keys.isEmpty {
                for key in keys {
                    do {
                        secrets[key] = try KeychainManager.readSecret(key: key)
                    } catch let error as KeychainError {
                        printError("Failed to read secret '\(key)': \(error.message)")
                        Foundation.exit(1)
                    } catch {
                        printError("Failed to read secret '\(key)': \(error)")
                        Foundation.exit(1)
                    }
                }
                resolvedAlias = resolvedAlias.referencingSecretsFromEnvironment(keys)
            }

            let code = await resolvedAlias.execute(aliasName: command, commandTemplate: alias.commandTemplate, displayCommands: displayCommands, secrets: secrets)
            // ez's exit status reflects the work it drove, so `ez test && deploy` behaves
            Foundation.exit(code)
        }
    }

    // Placeholder for potential options at the top level
    func run() throws {
        // This method will not be called because we handle everything in main()
    }
}
