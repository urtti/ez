import ArgumentParser
import Foundation

struct ExecuteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "<alias-name>",
        abstract: "Execute the command(s) associated with the given alias."
    )
}
