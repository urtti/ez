import Foundation

// How many ez runs this machine has done since it last booted — a cheap proxy for
// cold/warm caches and thermal state when reading a timing series later. The state file
// has a read-modify-write race across concurrent ez processes; an approximate counter is
// fine for a proxy, so no locking.
enum RunsSinceBoot {
    static func next() -> Int {
        guard let boot = bootEpoch() else { return 1 }
        let url = TelemetryPaths.root.appendingPathComponent("runs_since_boot")

        // The counter resets when the stored boot time no longer matches this boot
        var count = 1
        if let stored = try? String(contentsOf: url, encoding: .utf8) {
            let parts = stored.split(separator: " ")
            if parts.count == 2, Int(parts[0]) == boot, let previous = Int(parts[1]) {
                count = previous + 1
            }
        }
        try? TelemetryPaths.prepareRoot()
        try? "\(boot) \(count)".write(to: url, atomically: true, encoding: .utf8)
        return count
    }

    // kern.boottime is a timeval; its seconds field identifies the current boot
    private static func bootEpoch() -> Int? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 else { return nil }
        return Int(bootTime.tv_sec)
    }
}
