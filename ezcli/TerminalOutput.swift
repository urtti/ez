import Foundation

func printTimeTaken(fromStart startTime: Date, jobTitle: String = "", prefix: String = "", terminator: String = "\n") {
    let timeInterval = Date().timeIntervalSince(startTime)
    if timeInterval < 1 {
        // Less than 1 second, display in milliseconds
        let milliseconds = timeInterval * 1000
        print("\(prefix)🐘⏱️ \(jobTitle)\(String(format: "%.0f ms", milliseconds))".format(bold: true, color: .green), terminator: terminator)
    } else if timeInterval < 60 {
        // Less than 1 minute, display in seconds with 3 decimals
        print("\(prefix)🐘⏱️ \(jobTitle)\(String(format: "%.3f s", timeInterval))".format(bold: true, color: .green), terminator: terminator)
    } else {
        // 1 minute or more, display in minutes and seconds
        let minutes = Int(timeInterval) / 60
        let seconds = timeInterval.truncatingRemainder(dividingBy: 60)
        print("\(prefix)🐘⏱️ \(jobTitle)\(String(format: "%d min, %.2f s", minutes, seconds))".format(bold: true, color: .green), terminator: terminator)
    }
    if terminator != "\n" {
        fflush(stdout) // Ensures the text is flushed immediately to the console
    }
}

func printError(_ text: String) {
    fputs("🐘 ERROR: \(text)\n", stderr)
}

enum FontColor: String {
    case black = "30"
    case red = "31"
    case green = "32"
    case yellow = "33"
    case blue = "34"
    case magenta = "35"
    case cyan = "36"
    case white = "37"
}

extension String {
    func format(bold: Bool, color: FontColor) -> String {
        bold ? "\u{001B}[1;\(color.rawValue)m\(self)\u{001B}[0m" : "\u{001B}[\(color.rawValue)m\(self)\u{001B}[0m"
    }

    func formatBold() -> String {
        "\u{001B}[1m\(self)\u{001B}[0m" // Bold with default color
    }

    func containsExactMatch(of searchTerm: String) -> Bool {
        // Define the regular expression pattern with word boundaries
        let pattern = "\\b\(searchTerm)\\b"

        // Create a regular expression instance
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        // Search for matches in the command string
        let range = NSRange(self.startIndex..., in: self)
        let matches = regex?.matches(in: self, options: [], range: range)

        // Check if there is at least one match
        return matches?.count ?? 0 > 0
    }
}
