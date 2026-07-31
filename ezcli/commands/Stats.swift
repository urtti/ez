import ArgumentParser
import Foundation

private let RECENT_RUN_LIMIT = 20

struct Stats: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Shows run history and timing trends of aliases in this directory."
    )

    @Argument(help: "The name of the alias to show history for. Omit to summarize every alias with history.")
    var name: String?

    func run() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        if let name {
            await showHistory(of: name, cwd: cwd)
        } else {
            await showOverview(cwd: cwd)
        }
    }

    private func showHistory(of name: String, cwd: String) async {
        let runs = await RunStore.shared.recent(cwd: cwd, alias: name, limit: RECENT_RUN_LIMIT)

        if runs.isEmpty {
            print("🐘 No run history for \("ez \(name)".format(bold: true, color: .blue)) in this directory yet. Run it once and it shows up here.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        print("🐘 Recent runs \("ez \(name)".format(bold: true, color: .blue)) (\(runs.count))".formatBold())
        let durations = runs.map { formatDuration(milliseconds: $0.durationMs) }
        let maxDurationLength = durations.max(by: { $0.count < $1.count })?.count ?? 0
        for (run, duration) in zip(runs, durations) {
            let padded = String(repeating: " ", count: max(0, maxDurationLength - duration.count)) + duration
            let status = run.exitCode == 0 ? "ok".format(bold: true, color: .green) : "exit \(run.exitCode)".format(bold: true, color: .red)
            print("\(formatter.string(from: run.startedAt))  \(padded.format(bold: true, color: .green))  \(status)")
        }

        guard let summary = await RunStore.shared.summary(cwd: cwd, alias: name) else {
            print("")
            print("🐘 No successful runs yet, so there is nothing to summarize.")
            return
        }

        print("")
        print("🐘 Summary \("ez \(name)".format(bold: true, color: .blue)) (\(summary.count) successful run(s))".formatBold())
        let stats = [
            "min \(formatDuration(milliseconds: summary.minMs))",
            "median \(formatDuration(milliseconds: summary.medianMs))",
            "p90 \(formatDuration(milliseconds: summary.p90Ms))",
            "max \(formatDuration(milliseconds: summary.maxMs))"
        ].joined(separator: "  ")
        print(stats.format(bold: true, color: .green))
        print("trend \(summary.trend.arrow) \(summary.trend.sentence.format(bold: true, color: summary.trend.color))")
    }

    private func showOverview(cwd: String) async {
        let names = await RunStore.shared.aliasesWithHistory(cwd: cwd)

        if names.isEmpty {
            print("🐘 No run history in this directory yet. Run an alias and it shows up here.")
            return
        }

        let maxLengthAliasName = names.max(by: { $0.count < $1.count })?.count ?? 0
        print("🐘 Run history".formatBold())
        for aliasName in names {
            // Pad the name with spaces for nice formatting
            let paddingCount = max(0, maxLengthAliasName - aliasName.count)
            let label = "ez \(aliasName) " + String(repeating: " ", count: paddingCount)
            // Both branches count over every run, so the two lines share a denominator
            let total = await RunStore.shared.runCount(cwd: cwd, alias: aliasName)
            guard let summary = await RunStore.shared.summary(cwd: cwd, alias: aliasName) else {
                print("\(label.format(bold: true, color: .blue)) \("\(total) run(s), none successful".format(bold: true, color: .red))")
                continue
            }
            let counted = "\(summary.count) of \(total) run(s) ok  median \(formatDuration(milliseconds: summary.medianMs))"
            print("\(label.format(bold: true, color: .blue)) \(counted.format(bold: true, color: .green))  \(summary.trend.arrow) \(summary.trend.label.format(bold: true, color: summary.trend.color))")
        }
    }
}
