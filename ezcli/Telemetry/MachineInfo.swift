import Foundation

// Hardware and OS facts recorded with every run. Nothing aggregates them yet — they ship
// now because rows written without specs can never be backfilled, and later cohorting is
// keyed on hardware spec, never on person. All reads are sysctl calls: no process spawns,
// effectively free per invocation.
struct MachineInfo: Sendable {
    let model: String
    let cpuBrand: String
    let performanceCores: Int
    let efficiencyCores: Int
    let memoryBytes: Int64
    let osVersion: String

    static func current() -> MachineInfo {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return MachineInfo(
            model: sysctlString("hw.model") ?? "unknown",
            cpuBrand: sysctlString("machdep.cpu.brand_string") ?? "unknown",
            // Intel Macs predate the P/E split and lack the perflevel keys: every logical
            // core counts as a performance core there, with zero efficiency cores.
            performanceCores: Int(sysctlInt("hw.perflevel0.logicalcpu") ?? sysctlInt("hw.logicalcpu") ?? 0),
            efficiencyCores: Int(sysctlInt("hw.perflevel1.logicalcpu") ?? 0),
            memoryBytes: sysctlInt("hw.memsize") ?? 0,
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        )
    }

    // The pseudonymous per-machine identity: a locally generated UUID persisted at
    // <root>/machine_id. Never derived from hostname or username — a name-based ID would
    // turn the analytics into a surveillance vector by accident.
    static func persistedID() -> String {
        let url = TelemetryPaths.root.appendingPathComponent("machine_id")
        if let stored = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let fresh = UUID().uuidString
        try? TelemetryPaths.prepareRoot()
        try? fresh.write(to: url, atomically: true, encoding: .utf8)
        return fresh
    }
}

// sysctlbyname wants a caller-sized buffer: ask for the size first, then read into one
// that big. These keys are static hardware facts, so the size cannot change between calls.
private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
}

// Integer keys vary in width (core counts are 32-bit, hw.memsize 64-bit). Reading into a
// zeroed Int64 handles both: the kernel fills the low bytes and little-endian does the rest.
private func sysctlInt(_ name: String) -> Int64? {
    var value: Int64 = 0
    var size = MemoryLayout<Int64>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
}
