import ArgumentParser
import Foundation

struct RemoveSecret: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove-secret",
        abstract: "Remove a secret from Apple Keychain."
    )

    @Argument(help: "The secret key name to remove.")
    var key: String

    func run() throws {
        do {
            try KeychainManager.removeSecret(key: key)
            print("🐘 Secret '\(key)' removed from keychain.".format(bold: true, color: .green))
        } catch let error as KeychainError {
            printError(error.message)
            Foundation.exit(1)
        }
    }
}
