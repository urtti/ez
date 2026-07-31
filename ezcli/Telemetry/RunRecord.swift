import Foundation

struct RunRecord: Sendable {
    let cwd: String
    let aliasName: String
    let commandTemplate: String
    let executionType: ExecutionType
    let exitCode: Int32
    let durationMs: Int
    let startedAt: Date
}
