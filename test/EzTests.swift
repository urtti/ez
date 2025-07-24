@testable import ezcli
import XCTest

final class EzTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let localTestFile = Scope.local.getURL()
        let globalTestFile = Scope.global.getURL()
        try? FileManager.default.removeItem(at: localTestFile)
        try? FileManager.default.removeItem(at: globalTestFile)
    }

    override func tearDown() {
        let localTestFile = Scope.local.getURL()
        let globalTestFile = Scope.global.getURL()
        try? FileManager.default.removeItem(at: localTestFile)
        try? FileManager.default.removeItem(at: globalTestFile)
        super.tearDown()
    }

    // MARK: - AliasCollection Tests

    func testAliasCollectionInitialization() {
        let localCollection = AliasCollection(scope: Scope.local)
        XCTAssertNotNil(localCollection)

        let globalCollection = AliasCollection(scope: Scope.global)
        XCTAssertNotNil(globalCollection)
    }

    func testAddAndRetrieveAlias() {
        var collection = AliasCollection(scope: .local)
        let newAlias = Alias(executionType: .sequential, commands: ["echo", "hello"], description: "Prints hello")
        collection = collection.addAlias(name: "hello", alias: newAlias)

        let retrievedAlias = collection.alias(for: "hello")
        XCTAssertNotNil(retrievedAlias)
        XCTAssertEqual(retrievedAlias?.commands, ["echo", "hello"])
    }

    func testRemoveAlias() {
        let newAlias = Alias(executionType: .sequential, commands: ["echo", "hello"], description: "Prints hello")
        _ = AliasCollection(scope: .local).addAlias(name: "hello", alias: newAlias)

        AliasCollection.removeAlias(name: "hello", scope: .local)
        let retrievedAlias = AliasCollection(scope: .local).alias(for: "hello")
        XCTAssertNil(retrievedAlias)
    }

    func testLongestAliasName() {
        var collection = AliasCollection(scope: .local)
        collection = collection.addAlias(name: "short", alias: Alias(executionType: .sequential, commands: [], description: nil))
        collection = collection.addAlias(name: "verylongname", alias: Alias(executionType: .sequential, commands: [], description: nil))

        XCTAssertEqual(collection.longestAliasName(), 12)
    }

    func testIsEmpty() {
        let emptyCollection = AliasCollection(scope: .local)
        XCTAssertTrue(emptyCollection.isEmpty)

        var collection = AliasCollection(scope: .local)
        collection = collection.addAlias(name: "test", alias: Alias(executionType: .sequential, commands: [], description: nil))
        XCTAssertFalse(collection.isEmpty)
    }

    // MARK: - Alias Tests

    func testAliasCommandsDescriptionSequential() {
        let alias = Alias(executionType: .sequential, commands: ["ls", "-l", "-a"], description: nil)
        XCTAssertEqual(alias.commandsDescription, "ls -l -a")
    }

    func testAliasCommandsDescriptionParallel() {
        let alias = Alias(executionType: .parallel, commands: ["ls", "-l", "-a"], description: nil)
        XCTAssertEqual(alias.commandsDescription, "ls | -l | -a")
    }

    // MARK: - Scope Tests

    func testScopeGetURL() {
        let isUnitTest = ProcessInfo.processInfo.environment["EZCLI_UNIT_TEST"] == "1"
        let globalURL = Scope.global.getURL()
        let localURL = Scope.local.getURL()
        if isUnitTest {
            XCTAssertEqual(globalURL.lastPathComponent, ".ez_cli_global_test.json")
            XCTAssertEqual(localURL.lastPathComponent, ".ez_cli_test.json")
        } else {
            XCTAssertEqual(globalURL.lastPathComponent, ".ez_cli_global.json")
            XCTAssertEqual(localURL.lastPathComponent, ".ez_cli.json")
        }
    }

    func testScopeRunContextDescription() {
        XCTAssertEqual(Scope.local.runContextDescription(), "Execute in this directory")
        XCTAssertEqual(Scope.global.runContextDescription(), "Execute from anywhere")
    }

    func testScopeTitle() {
        XCTAssertEqual(Scope.local.title(), "Local")
        XCTAssertEqual(Scope.global.title(), "Global")
    }
//
//    // MARK: - String Extension Tests
//
//    func testStringFormatBoldAndColor() {
//        let formattedString = "Test".format(bold: true, color: .red)
//        XCTAssertEqual(formattedString, "\u{001B}[1;31mTest\u{001B}[0m")
//
//        let formattedString2 = "Test".format(bold: false, color: .blue)
//        XCTAssertEqual(formattedString2, "\u{001B}[34mTest\u{001B}[0m")
//    }
//
//    func testStringFormatBold() {
//        let boldString = "Test".formatBold()
//        XCTAssertEqual(boldString, "\u{001B}[1mTest\u{001B}[0m")
//    }
//
//    func testStringContainsExactMatch() {
//        let testString = "ez add myalias ls -l"
//        XCTAssertTrue(testString.containsExactMatch(of: "ls"))
//        XCTAssertFalse(testString.containsExactMatch(of: "l"))
//        XCTAssertTrue(testString.containsExactMatch(of: "add"))
//        XCTAssertFalse(testString.containsExactMatch(of: "adding"))
//    }
//
//    // MARK: - Command Line Parsing (Minimal - More Extensive Testing Required via Integration Tests)
//
//    func testCommandLineParsing() throws {
//        //  This is difficult to test exhaustively without mocking out the environment,
//        //  which is beyond the scope of these basic unit tests.  Integration tests
//        //  are more suitable for verifying command-line argument parsing.
//
//        // A very basic test that the command line parser initializes.
//        XCTAssertNoThrow(try Ez.parse(["ez", "list"]))
//    }

    // MARK: -  File System Operations (Integration Tests Recommended)

    // File system operations (reading/writing alias files) are better suited
    // for integration tests, as they involve external dependencies. Unit tests
    // would require extensive mocking, which can be cumbersome and less reliable.
    // Additionally, the `addAlias` and `removeAlias` static functions print to standard out.

    // MARK: - Concurrency

    // Concurrency tests need proper mocking of async calls. It goes beyond basic unit testing.
}
