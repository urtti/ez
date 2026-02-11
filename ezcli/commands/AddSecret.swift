import ArgumentParser
import Foundation

struct AddSecret: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-secret",
        abstract: "Store a secret in Apple Keychain for use in aliases as {EZ_*} placeholders."
    )

    @Option(name: .long, help: "The secret key name (must start with EZ_ and contain only uppercase letters, digits, underscores).")
    var key: String

    @Option(name: .long, help: "The secret value to store.")
    var value: String

    @Flag(name: .long, help: "Overwrite the secret if it already exists.")
    var force: Bool = false

    func run() throws {
        let keyPattern = "^EZ_[A-Z0-9_]+$"
        guard key.range(of: keyPattern, options: .regularExpression) != nil else {
            printError("Invalid key '\(key)'. Must start with EZ_ and contain only uppercase letters, digits, and underscores.")
            Foundation.exit(1)
        }

        do {
            try KeychainManager.addSecret(key: key, value: value, force: force)
            print("🐘 Secret '\(key)' stored in keychain.".format(bold: true, color: .green))
        } catch let error as KeychainError {
            printError(error.message)
            Foundation.exit(1)
        }
    }
}
