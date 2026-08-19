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

    @Flag(name: .shortAndLong, help: "Also show the machine context recorded with each run.")
    var verbose = false

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
            // runs-since-boot is the per-row part of the context: a cold/warm hint next to the timing
            let bootNote = verbose ? run.context.map { "  run \($0.runsSinceBoot) since boot" } ?? "" : ""
            print("\(formatter.string(from: run.startedAt))  \(padded.format(bold: true, color: .green))  \(status)\(bootNote)")
        }

        // The specs are identical on every row from one machine, so they print once
        if verbose, let context = runs.compactMap(\.context).first {
            print("")
            print("🐘 Machine (as recorded on the latest run)".formatBold())
            print(describeMachine(context.machine).format(bold: true, color: .green))
            print("machine id \(context.machineID)")
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

    private func describeMachine(_ machine: MachineInfo) -> String {
        // Intel Macs record zero efficiency cores; a P/E split of "10P + 0E" would be noise there
        let cores = machine.efficiencyCores > 0
            ? "\(machine.performanceCores)P + \(machine.efficiencyCores)E cores"
            : "\(machine.performanceCores) cores"
        let memory = String(format: "%.0f GB", Double(machine.memoryBytes) / 1_073_741_824)
        return "\(machine.model)  \(machine.cpuBrand)  \(cores)  \(memory)  macOS \(machine.osVersion)"
    }

    private func showOverview(cwd: String) async {
        let names = await RunStore.shared.aliasesWithHistory(cwd: cwd)

        if names.isEmpty {
            print("🐘 No run history in this directory yet. Run an alias and it shows up here.")
            return
        }

        // Gather plain text first: columns must be padded before colour codes wrap them,
        // and the widths depend on every row
        var rows: [(alias: String, runs: String, median: String, trend: String, trendColor: FontColor, allFailed: Bool)] = []
        for aliasName in names {
            // Both branches count over every run, so all rows share a denominator
            let total = await RunStore.shared.runCount(cwd: cwd, alias: aliasName)
            if let summary = await RunStore.shared.summary(cwd: cwd, alias: aliasName) {
                rows.append((
                    alias: "ez \(aliasName)",
                    runs: "\(summary.count) of \(total)",
                    median: formatDuration(milliseconds: summary.medianMs),
                    trend: "\(summary.trend.arrow) \(summary.trend.label)",
                    trendColor: summary.trend.color,
                    allFailed: false
                ))
            } else {
                rows.append((
                    alias: "ez \(aliasName)",
                    runs: "0 of \(total)",
                    median: "—",
                    trend: "none successful",
                    trendColor: .red,
                    allFailed: true
                ))
            }
        }

        let aliasWidth = max("alias".count, rows.map { $0.alias.count }.max() ?? 0)
        let runsWidth = max("success rate".count, rows.map { $0.runs.count }.max() ?? 0)
        let medianWidth = max("median duration".count, rows.map { $0.median.count }.max() ?? 0)

        func padded(_ text: String, to width: Int) -> String {
            text + String(repeating: " ", count: max(0, width - text.count))
        }

        print("🐘 Run history".formatBold())
        print("\(padded("alias", to: aliasWidth))  \(padded("success rate", to: runsWidth))  \(padded("median duration", to: medianWidth))  duration trend")
        for row in rows {
            let alias = padded(row.alias, to: aliasWidth).format(bold: true, color: .blue)
            let runs = padded(row.runs, to: runsWidth).format(bold: true, color: row.allFailed ? .red : .green)
            let median = padded(row.median, to: medianWidth).format(bold: true, color: row.allFailed ? .red : .green)
            print("\(alias)  \(runs)  \(median)  \(row.trend.format(bold: true, color: row.trendColor))")
        }
    }
}
