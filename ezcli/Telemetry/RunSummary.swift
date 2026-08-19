import Foundation

private let TREND_WINDOW = 5
private let TREND_THRESHOLD = 0.15

// A run must beat this to be worth commenting on. Annotating `ez gs` forty times a
// day is noise, and sub-second runs are dominated by process startup anyway.
let OUTLIER_MIN_MS = 500
// Enough prior runs that the baseline median means something
private let OUTLIER_BASELINE_RUNS = 5
// How far back the baseline looks
let OUTLIER_BASELINE_WINDOW = 10

// One run measured against the median of the successful runs before it. Initialises to
// nil when there is no trustworthy baseline or the run is unremarkable, so normal run
// output is untouched unless there is genuinely something to say.
struct RunOutlier: Sendable {
    let percent: Int
    let isSlower: Bool
    let baselineMedianMs: Int

    // priorDurations must be successful runs only, most recent first, excluding this run
    init?(durationMs: Int, priorDurations: [Int]) {
        guard priorDurations.count >= OUTLIER_BASELINE_RUNS else { return nil }

        let baseline = median(ofSorted: priorDurations.sorted())
        // A zero baseline cannot be compared against — any change would read as infinite
        guard baseline > 0 else { return nil }
        // Gate on whichever is larger, not on this run alone: an alias that normally takes
        // 10 s and suddenly takes 2 s is exactly the speedup worth reporting, and gating on
        // the run would silence it for dropping under the threshold
        guard max(durationMs, baseline) >= OUTLIER_MIN_MS else { return nil }

        let change = (Double(durationMs) - Double(baseline)) / Double(baseline)
        guard abs(change) >= TREND_THRESHOLD else { return nil }

        percent = Int((abs(change) * 100).rounded())
        isSlower = change > 0
        baselineMedianMs = baseline
    }

    var note: String {
        let direction = isSlower ? "slower" : "faster"
        return "\(isSlower ? "↑" : "↓") \(percent)% \(direction) than median \(formatDuration(milliseconds: baselineMedianMs))"
    }

    var color: FontColor {
        isSlower ? .red : .green
    }
}

// Statistics over successful runs only, so a failed or interrupted fast run never drags the median
struct RunSummary: Sendable {
    let count: Int
    let minMs: Int
    let medianMs: Int
    let p90Ms: Int
    let maxMs: Int
    let trend: RunTrend

    // durations must be ordered most recent first
    init(recentFirstDurations durations: [Int]) {
        let sorted = durations.sorted()
        count = sorted.count
        minMs = sorted.first ?? 0
        maxMs = sorted.last ?? 0
        medianMs = median(ofSorted: sorted)
        p90Ms = percentile(0.9, ofSorted: sorted)
        trend = RunTrend(recentFirstDurations: durations)
    }
}

enum RunTrend: Sendable {
    case insufficientData(available: Int, needed: Int)
    case noBaseline(recentMedianMs: Int)
    case steady(recentMedianMs: Int, previousMedianMs: Int)
    case slower(percent: Int, recentMedianMs: Int, previousMedianMs: Int)
    case faster(percent: Int, recentMedianMs: Int, previousMedianMs: Int)

    // Median of the most recent N against the N before it, reported only past the threshold
    init(recentFirstDurations durations: [Int]) {
        guard durations.count >= 2 * TREND_WINDOW else {
            self = .insufficientData(available: durations.count, needed: 2 * TREND_WINDOW)
            return
        }

        let recent = median(ofSorted: durations[0..<TREND_WINDOW].sorted())
        let previous = median(ofSorted: durations[TREND_WINDOW..<(2 * TREND_WINDOW)].sorted())
        // A zero baseline cannot be compared against — any change would read as infinite
        guard previous > 0 else {
            self = .noBaseline(recentMedianMs: recent)
            return
        }

        let change = (Double(recent) - Double(previous)) / Double(previous)
        if abs(change) < TREND_THRESHOLD {
            self = .steady(recentMedianMs: recent, previousMedianMs: previous)
        } else if change > 0 {
            self = .slower(percent: Int((change * 100).rounded()), recentMedianMs: recent, previousMedianMs: previous)
        } else {
            self = .faster(percent: Int((-change * 100).rounded()), recentMedianMs: recent, previousMedianMs: previous)
        }
    }

    var arrow: String {
        return switch self {
        case .insufficientData, .noBaseline: "·"
        case .steady: "→"
        case .slower: "↑"
        case .faster: "↓"
        }
    }

    var color: FontColor {
        return switch self {
        case .insufficientData, .noBaseline: .blue
        case .steady: .green
        case .slower: .red
        case .faster: .green
        }
    }

    var label: String {
        return switch self {
        case .insufficientData(let available, let needed):
            "needs \(needed - available) more run\(needed - available == 1 ? "" : "s")"
        case .noBaseline: "no baseline"
        case .steady: "steady"
        case .slower(let percent, _, _): "\(percent)% slower"
        case .faster(let percent, _, _): "\(percent)% faster"
        }
    }

    var sentence: String {
        switch self {
        case .insufficientData(let available, let needed):
            let remaining = needed - available
            return "\(remaining) more successful run\(remaining == 1 ? "" : "s") needed to show perf trends — \(available) of \(needed) so far"
        case .noBaseline(let recent):
            return "no baseline — the previous \(TREND_WINDOW) runs median 0 ms, nothing to compare last \(TREND_WINDOW) median \(formatDuration(milliseconds: recent)) against"
        case .steady(let recent, let previous):
            return "steady — last \(TREND_WINDOW) median \(formatDuration(milliseconds: recent)) vs \(formatDuration(milliseconds: previous)) before"
        case .slower(let percent, let recent, let previous), .faster(let percent, let recent, let previous):
            let direction = if case .slower = self { "slower" } else { "faster" }
            return "\(percent)% \(direction) — last \(TREND_WINDOW) median \(formatDuration(milliseconds: recent)) vs \(formatDuration(milliseconds: previous)) before"
        }
    }
}

private func median(ofSorted values: [Int]) -> Int {
    guard !values.isEmpty else { return 0 }
    let middle = values.count / 2
    if values.count % 2 == 1 {
        return values[middle]
    }
    return Int(((Double(values[middle - 1]) + Double(values[middle])) / 2).rounded())
}

// Nearest-rank percentile
private func percentile(_ fraction: Double, ofSorted values: [Int]) -> Int {
    guard !values.isEmpty else { return 0 }
    let rank = Int((fraction * Double(values.count)).rounded(.up))
    return values[min(max(rank - 1, 0), values.count - 1)]
}
