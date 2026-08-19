import Foundation

struct RunRecord: Sendable {
    let cwd: String
    let aliasName: String
    let commandTemplate: String
    let executionType: ExecutionType
    let exitCode: Int32
    let durationMs: Int
    let startedAt: Date
    // nil on rows written before schema v2
    let context: RunContext?
}

// Machine and boot facts captured alongside each run (schema v2)
struct RunContext: Sendable {
    let machineID: String
    let machine: MachineInfo
    let runsSinceBoot: Int

    static func capture() -> RunContext {
        RunContext(
            machineID: MachineInfo.persistedID(),
            machine: MachineInfo.current(),
            runsSinceBoot: RunsSinceBoot.next()
        )
    }
}
