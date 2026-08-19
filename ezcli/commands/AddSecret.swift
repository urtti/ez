import ArgumentParser
import Darwin
import Foundation

struct AddSecret: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-secret",
        abstract: "Store a secret in Apple Keychain for use in aliases as {EZ_*} placeholders.",
        discussion: "Omit --value to enter the secret at a hidden prompt, or pipe it on stdin."
    )

    @Option(name: .long, help: "The secret key name (must start with EZ_ and contain only uppercase letters, digits, underscores).")
    var key: String

    @Option(name: .long, help: "The secret value to store. Deprecated: exposes the value to shell history and ps; prefer the prompt or stdin.")
    var value: String?

    @Flag(name: .long, help: "Overwrite the secret if it already exists.")
    var force: Bool = false

    func run() throws {
        let keyPattern = "^EZ_[A-Z0-9_]+$"
        guard key.range(of: keyPattern, options: .regularExpression) != nil else {
            printError("Invalid key '\(key)'. Must start with EZ_ and contain only uppercase letters, digits, and underscores.")
            Foundation.exit(1)
        }

        let secretValue: String
        if let value {
            fputs("🐘 ⚠️  --value exposes the secret to shell history and ps; pipe the value on stdin or omit --value to be prompted. --value will be removed in a future release.\n", stderr)
            secretValue = value
        } else if isatty(STDIN_FILENO) != 0 {
            var buffer = [CChar](repeating: 0, count: 4096)
            guard let entered = readpassphrase("Enter value for \(key): ", &buffer, buffer.count, RPP_ECHO_OFF) else {
                printError("Could not read secret from terminal.")
                Foundation.exit(1)
            }
            secretValue = String(cString: entered)
        } else {
            guard let line = readLine(strippingNewline: true) else {
                printError("No value provided on stdin.")
                Foundation.exit(1)
            }
            secretValue = line
        }

        guard !secretValue.isEmpty else {
            printError("Secret value must not be empty.")
            Foundation.exit(1)
        }

        do {
            try KeychainManager.addSecret(key: key, value: secretValue, force: force)
            print("🐘 Secret '\(key)' stored in keychain.".format(bold: true, color: .green))
        } catch let error as KeychainError {
            printError(error.message)
            Foundation.exit(1)
        }
    }
}
