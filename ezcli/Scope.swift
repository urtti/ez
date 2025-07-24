import Foundation

enum Scope: String {
    case global
    case local

    func runContextDescription() -> String {
        return switch self {
        case .local: "Execute in this directory"
        case .global: "Execute from anywhere"
        }
    }

    func getURL() -> URL {
        if ProcessInfo.processInfo.environment["EZCLI_UNIT_TEST"] == "1" {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            return switch self {
            case .global: tempDir.appendingPathComponent(".ez_cli_global_test.json")
            case .local: tempDir.appendingPathComponent(".ez_cli_test.json")
            }
        }
        #if UNIT_TEST
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil) // Create if doesn't exist

        return switch self {
        case .global: tempDir.appendingPathComponent(".ez_cli_global_test.json")
        case .local: tempDir.appendingPathComponent(".ez_cli_test.json")
        }
        #else
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            print("\u{274C} ERROR: Unit tests are running without the UNIT_TEST flag set. Aborting.\n\nPlease run tests using './run-test.sh' or 'swift test -Xswiftc -DUNIT_TEST' to avoid modifying your real configuration files.")
            exit(1)
        }
        #endif
        return switch self {
        case .global: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ez_cli_global.json")
        case .local: URL(fileURLWithPath: FileManager.default.currentDirectoryPath.appending("/.ez_cli.json"))
        }
        #endif
    }

    func title() -> String {
        rawValue.capitalized
    }
}
