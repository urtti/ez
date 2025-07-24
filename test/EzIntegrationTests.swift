import XCTest

final class EzIntegrationTests: XCTestCase {
    func testEzVersion() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["--version"]
        process.environment = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let versionPattern = #"v?\d+\.\d+\.\d+"#
        let regex = try! NSRegularExpression(pattern: versionPattern)
        let range = NSRange(output.startIndex..., in: output)
        let match = regex.firstMatch(in: output, options: [], range: range)
        XCTAssertNotNil(match, "Output should contain a semantic version (vX.Y.Z). Output: \(output)")
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testEzHelp() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["--help"]
        process.environment = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("usage"), "Output should contain usage/help. Output: \(output)")
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testEzAddListRemove() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }

        // Add
        var process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["add", "testalias", "echo", "integration"]
        process.environment = env
        process.currentDirectoryURL = tempDir
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let addOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(addOutput.contains("testalias"), "Add output: \(addOutput)")
        XCTAssertEqual(process.terminationStatus, 0)

        // List
        process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["list"]
        process.environment = env
        process.currentDirectoryURL = tempDir
        let listPipe = Pipe()
        process.standardOutput = listPipe
        process.standardError = listPipe
        try process.run()
        process.waitUntilExit()
        let listOutput = String(data: listPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(listOutput.contains("testalias"), "List output: \(listOutput)")
        XCTAssertEqual(process.terminationStatus, 0)

        // Remove
        process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["remove", "testalias"]
        process.environment = env
        process.currentDirectoryURL = tempDir
        let removePipe = Pipe()
        process.standardOutput = removePipe
        process.standardError = removePipe
        try process.run()
        process.waitUntilExit()
        let removeOutput = String(data: removePipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(removeOutput.contains("removed") || removeOutput.lowercased().contains("removed"), "Remove output: \(removeOutput)")
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testEzUnknownCommand() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["unknowncmd123"]
        process.environment = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("unknown alias") || output.lowercased().contains("error"), "Output: \(output)")
    }

    func testEzAddProtectedKeyword() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["add", "add", "echo", "shouldfail"]
        process.environment = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("protected keyword"), "Output: \(output)")
        XCTAssertNotEqual(process.terminationStatus, 0)
    }

    func testEzRemoveNonExistentAlias() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["remove", "doesnotexist"]
        process.environment = env
        process.currentDirectoryURL = tempDir
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("no alias named"), "Output: \(output)")
    }

    func testEzListWhenEmpty() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["list"]
        process.environment = env
        process.currentDirectoryURL = tempDir
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("no aliases defined"), "Output: \(output)")
    }

    func testEzAddMissingArguments() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["add"]
        process.environment = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("usage") || output.lowercased().contains("must specify"), "Output: \(output)")
        XCTAssertNotEqual(process.terminationStatus, 0)
    }

    func testMalformedAliasFile() throws {
        let localAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_test.json")
        let globalAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_global_test.json")
        try "{not a json}".write(to: localAliasFile, atomically: true, encoding: .utf8)
        try "{not a json}".write(to: globalAliasFile, atomically: true, encoding: .utf8)
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["list"]
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("error") || output.lowercased().contains("failed to decode"), "Output: \(output)")
        try? FileManager.default.removeItem(at: localAliasFile)
        try? FileManager.default.removeItem(at: globalAliasFile)
    }

    func testMalformedGlobalAliasFile() throws {
        let globalAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_global_test.json")
        let localAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_test.json")
        try "{not a json}".write(to: globalAliasFile, atomically: true, encoding: .utf8)
        try "{not a json}".write(to: localAliasFile, atomically: true, encoding: .utf8)
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["list"]
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("error") || output.lowercased().contains("failed to decode"), "Output: \(output)")
        try? FileManager.default.removeItem(at: localAliasFile)
        try? FileManager.default.removeItem(at: globalAliasFile)
    }

    func testMalformedLocalAliasFileWithNoGlobal() throws {
        let globalAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_global_test.json")
        let localAliasFile = FileManager.default.temporaryDirectory.appendingPathComponent("ez_cli_tests/.ez_cli_test.json")
        try? FileManager.default.removeItem(at: globalAliasFile) // ensure global does not exist
        try "{not a json}".write(to: localAliasFile, atomically: true, encoding: .utf8)
        let env = ProcessInfo.processInfo.environment.merging(["EZCLI_UNIT_TEST": "1"]) { $1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/ez")
        process.arguments = ["list"]
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.lowercased().contains("error") || output.lowercased().contains("failed to decode"), "Output: \(output)")
        try? FileManager.default.removeItem(at: localAliasFile)
        try? FileManager.default.removeItem(at: globalAliasFile)
    }
} 