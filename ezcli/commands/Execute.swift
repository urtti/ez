import ArgumentParser
import Foundation

// While not executed, this is needed for listing the commands in help
struct ExecuteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "<alias-name>",
        abstract: "Execute the command(s) associated with the given alias."
    )
}
