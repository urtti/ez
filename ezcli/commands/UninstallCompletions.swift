import ArgumentParser
import Foundation

struct UninstallCompletions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall-completions",
        abstract: "Remove shell tab completions for ez."
    )

    private static let startMarker = "# >>> ez completions >>>"
    private static let endMarker = "# <<< ez completions <<<"

    func run() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let zshrcPath = homeDir.appendingPathComponent(".zshrc")

        // Check if .zshrc exists
        guard FileManager.default.fileExists(atPath: zshrcPath.path) else {
            print("No ~/.zshrc file found.".format(bold: true, color: .yellow))
            return
        }

        var zshrcContent = try String(contentsOf: zshrcPath, encoding: .utf8)

        // Find both markers
        guard let startRange = zshrcContent.range(of: Self.startMarker),
              let endRange = zshrcContent.range(of: Self.endMarker) else {
            if zshrcContent.contains(Self.startMarker) || zshrcContent.contains(Self.endMarker) {
                printError("Found partial ez completions block in ~/.zshrc. Please remove manually.")
            } else {
                print("No ez completions found in ~/.zshrc".format(bold: true, color: .yellow))
            }
            return
        }

        // Verify end marker comes after start marker
        guard startRange.lowerBound < endRange.lowerBound else {
            printError("Malformed ez completions block in ~/.zshrc. Please remove manually.")
            return
        }

        // Determine the full range to remove (including surrounding newlines if present)
        var removeStart = startRange.lowerBound
        var removeEnd = endRange.upperBound

        // Include leading newline if present
        if removeStart > zshrcContent.startIndex {
            let beforeStart = zshrcContent.index(before: removeStart)
            if zshrcContent[beforeStart] == "\n" {
                removeStart = beforeStart
            }
        }

        // Include trailing newline if present
        if removeEnd < zshrcContent.endIndex && zshrcContent[removeEnd] == "\n" {
            removeEnd = zshrcContent.index(after: removeEnd)
        }

        zshrcContent.removeSubrange(removeStart..<removeEnd)

        // Clean up any extra blank lines that might remain at end
        while zshrcContent.hasSuffix("\n\n\n") {
            zshrcContent.removeLast()
        }

        try zshrcContent.write(to: zshrcPath, atomically: true, encoding: .utf8)

        print("Completions removed successfully!".format(bold: true, color: .green))
        print("")
        print("Changes will take effect in new terminal sessions.")
    }
}
