import ArgumentParser
import Foundation

private let PROTECTED_KEYWORDS = ["add", "remove", "list"]

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new alias to the collection."
    )

    @Flag(name: [.customShort("p"), .long], help: "Alias executes all commands in parallel. Note: Experimental state.")
    var parallel: Bool = false

    @Option(name: .shortAndLong, help: "A textual description; does not affect functionality.")
    var description: String?

    @Argument(help: "The name by which to call this alias.")
    var name: String

    @Argument(help: "The command(s) to save.")
    var commands: [String]

    func run() throws {
        // Create a new Alias
        if PROTECTED_KEYWORDS.contains(name) {
            printError("\(name) is a protected keyword. Please choose another name for your alias.")
            Foundation.exit(1)
        }
        let commandsToSave = commands
        if commands.isEmpty {
            printError("You must specify at least one command to add as an alias.")
            Foundation.exit(1)
        }
        // Always use local scope for now
        AliasCollection.addAlias(name: name, alias: Alias(
            executionType: parallel ? .parallel : .sequential,
            commands: commandsToSave,
            description: description
        ), scope: Scope.local)
    }
} 