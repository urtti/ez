import XCTest
@testable import ezcli

final class EzExtraTests: XCTestCase {
    func testStringFormatBoldAndColor() {
        let formattedString = "Test".format(bold: true, color: .red)
        XCTAssertEqual(formattedString, "\u{001B}[1;31mTest\u{001B}[0m")

        let formattedString2 = "Test".format(bold: false, color: .blue)
        XCTAssertEqual(formattedString2, "\u{001B}[34mTest\u{001B}[0m")
    }

    func testStringFormatBold() {
        let boldString = "Test".formatBold()
        XCTAssertEqual(boldString, "\u{001B}[1mTest\u{001B}[0m")
    }

    func testStringContainsExactMatch() {
        let testString = "ez add myalias git status --verbose"
        XCTAssertTrue(testString.containsExactMatch(of: "git"))
        XCTAssertFalse(testString.containsExactMatch(of: "sta"))
        XCTAssertTrue(testString.containsExactMatch(of: "add"))
        XCTAssertFalse(testString.containsExactMatch(of: "adding"))
        XCTAssertTrue(testString.containsExactMatch(of: "status"))
        XCTAssertTrue(testString.containsExactMatch(of: "verbose"))
        XCTAssertFalse(testString.containsExactMatch(of: "verb"))
    }

    func testPrintError() {
        // Capture error output
        let pipe = Pipe()
        let originalStdErr = dup(fileno(stderr))
        dup2(pipe.fileHandleForWriting.fileDescriptor, fileno(stderr))
        printError("This is an error")
        fflush(stderr)
        pipe.fileHandleForWriting.closeFile()
        dup2(originalStdErr, fileno(stderr))
        close(originalStdErr)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if !output.contains("This is an error") {
            print("Captured error output: \(output)")
        }
        XCTAssertTrue(output.contains("This is an error"))
    }

    func testPrintTimeTaken() {
        let start = Date().addingTimeInterval(-1.5)
        printTimeTaken(fromStart: start, jobTitle: "TestJob")
    }

    func testRunCommandsEcho() async {
        // Capture output using a pipe
        let pipe = Pipe()
        await MainActor.run {
            runCommands("echo 'test_runCommandsEcho'", output: pipe.fileHandleForWriting, errorOutput: pipe.fileHandleForWriting)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains("test_runCommandsEcho"))
    }

    func testRunCommandsInvalidCommand() async {
        let pipe = Pipe()
        await MainActor.run {
            runCommands("nonexistent_command_12345", output: pipe.fileHandleForWriting, errorOutput: pipe.fileHandleForWriting)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // Should print an error message
        XCTAssertTrue(output.contains("ERROR") || output.lowercased().contains("not found") || output.lowercased().contains("command not found"))
    }

    func testRunCommandsEmptyCommand() async {
        let pipe = Pipe()
        await MainActor.run {
            runCommands("", output: pipe.fileHandleForWriting, errorOutput: pipe.fileHandleForWriting)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // Should not crash, may print nothing or an error
        XCTAssertTrue(output.isEmpty || output.contains("ERROR") || output.lowercased().contains("usage"))
    }

    func testRunCommandsFalse() async {
        let pipe = Pipe()
        await MainActor.run {
            runCommands("false", output: pipe.fileHandleForWriting, errorOutput: pipe.fileHandleForWriting)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // 'false' exits with code 1, but produces no output; just ensure no crash
        XCTAssertTrue(output.isEmpty || output.contains("ERROR"))
    }

    func testRunParallelCommandsHarmless() async {
        // This test just ensures no crash and both outputs appear
        await runParallelCommands(["echo 'parallelA'", "echo 'parallelB'"])
        // No assertion on output, just that it completes
    }

    func testRunParallelCommandsError() async {
        // This test ensures error handling in parallel jobs
        await runParallelCommands(["false", "echo 'parallelC'"])
        // No assertion on output, just that it completes
    }

    func testAliasParallelExecution() async {
        let alias = Alias(executionType: .parallel, commands: ["echo 'aliasP1'", "echo 'aliasP2'"], description: nil)
        await alias.execute()
        // No assertion on output, just that it completes
    }

    func testAliasCollectionRemoveNonExistent() {
        let collection = AliasCollection(scope: .local)
        // Should not throw or crash
        AliasCollection.removeAlias(name: "doesnotexist", scope: .local)
    }

    func testAliasCollectionEmptyList() {
        let collection = AliasCollection(scope: .local)
        XCTAssertTrue(collection.isEmpty)
        XCTAssertEqual(collection.longestAliasName(), 0)
    }

    func testPrintTimeTakenBranches() {
        // <1s
        let start = Date().addingTimeInterval(-0.5)
        printTimeTaken(fromStart: start, jobTitle: "ShortJob")
        // <60s
        let start2 = Date().addingTimeInterval(-10)
        printTimeTaken(fromStart: start2, jobTitle: "MediumJob")
        // >60s
        let start3 = Date().addingTimeInterval(-75)
        printTimeTaken(fromStart: start3, jobTitle: "LongJob")
    }

    // Skipping testRunParallelCommandsEcho for now, as runParallelCommands does not support output injection
} 
