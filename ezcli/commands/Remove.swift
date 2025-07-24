import ArgumentParser
import Foundation

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Removes an alias."
    )

    @Argument(help: "The name of the alias to remove.")
    var name: String

    func run() throws {
        // Always use local scope for now
        AliasCollection.removeAlias(name: name, scope: Scope.local)
    }
} 