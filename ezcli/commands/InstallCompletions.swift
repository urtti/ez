import ArgumentParser
import Foundation

struct InstallCompletions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install-completions",
        abstract: "Install shell tab completions for ez."
    )

    private static let startMarker = "# >>> ez completions >>>"
    private static let endMarker = "# <<< ez completions <<<"

    private static let completionScript = """
\(startMarker)
_ez() {
    local -a aliases

    # Read local aliases
    if [[ -f .ez_cli.json ]]; then
        if command -v jq &>/dev/null; then
            aliases=("${(@f)$(jq -r '.aliases | keys[]' .ez_cli.json 2>/dev/null | sort)}")
        else
            aliases=("${(@f)$(sed -n '/"aliases"/,/^  }/p' .ez_cli.json 2>/dev/null | grep -E '^    "[^"]+"\\ *:' | sed 's/.*"\\([^"]*\\)".*/\\1/' | sort)}")
        fi
        aliases=(${aliases:#})  # Remove empty elements
    fi

    (( ${#aliases} )) && compadd -a aliases
}
compdef _ez ez
\(endMarker)
"""

    func run() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let zshrcPath = homeDir.appendingPathComponent(".zshrc")

        // Check if .zshrc exists
        var zshrcContent = ""
        if FileManager.default.fileExists(atPath: zshrcPath.path) {
            zshrcContent = try String(contentsOf: zshrcPath, encoding: .utf8)
        }

        // Check if already installed
        if zshrcContent.contains(Self.startMarker) {
            print("Completions are already installed in ~/.zshrc".format(bold: true, color: .yellow))
            print("Run 'ez uninstall-completions' first if you want to reinstall.")
            return
        }

        // Append completion script (ensure single newline separator)
        var newContent = zshrcContent
        if !newContent.isEmpty && !newContent.hasSuffix("\n") {
            newContent += "\n"
        }
        // Add blank line before our block for readability, but not if file is empty
        if !newContent.isEmpty && !newContent.hasSuffix("\n\n") {
            newContent += "\n"
        }
        newContent += Self.completionScript + "\n"
        try newContent.write(to: zshrcPath, atomically: true, encoding: .utf8)

        print("Completions installed successfully!".format(bold: true, color: .green))
        print("")
        print("To activate, either:")
        print("  1. Restart your terminal, or")
        print("  2. Run: " + "source ~/.zshrc".format(bold: true, color: .cyan))
    }
}
