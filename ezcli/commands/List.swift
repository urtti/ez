import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Lists all stored aliases."
    )

    @Flag(name: .shortAndLong, help: "Include file paths in output.")
    var verbose: Bool = false

    func run() throws {
        let localAliasCollection = AliasCollection(scope: Scope.local)
        let maxLengthAliasName = localAliasCollection.longestAliasName()

        if localAliasCollection.isEmpty {
            print("🐘 No aliases defined. Add some with 'ez add'.")
        } else {
            listAliases(aliasCollection: localAliasCollection, scope: Scope.local, verbose: verbose, maxLengthAliasName: maxLengthAliasName)
        }
    }

    private func listAliases(aliasCollection: AliasCollection, scope: Scope, verbose: Bool, maxLengthAliasName: Int) {
        print("🐘 Aliases \(verbose ? "(\(scope.getURL().relativePath))" : "")".formatBold())
        for item in aliasCollection.aliases {
            // Pad the name with spaces for nice formatting
            let paddingCount = max(0, maxLengthAliasName - item.key.count)
            let name = "ez \(item.key) " + String(repeating: " ", count: paddingCount)
            print("\(name.format(bold: true, color: item.value.executionType.color)) \(item.value.commandsDescription.format(bold: true, color: .green))")

            if let description = item.value.description, !description.isEmpty, verbose {
                print("   \(description)")
            }
        }
    }
} 
