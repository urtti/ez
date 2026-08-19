import Foundation

enum TelemetryPaths {
    // Root is $EZCLI_HOME if set, so test runs never touch the real ~/.ez
    static var root: URL {
        let environment = ProcessInfo.processInfo.environment
        if let home = environment["EZCLI_HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        if environment["EZCLI_UNIT_TEST"] == "1" {
            return FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ez", isDirectory: true)
    }

    static var databaseURL: URL {
        root.appendingPathComponent("runs.db")
    }

    static func prepareRoot() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
    }
}
