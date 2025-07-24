# ezcli

A macOS CLI tool for managing and executing command aliases, written in Swift.

## Building

To build the project using Swift Package Manager:

```sh
swift build
```

## Running

To run the CLI tool:

```sh
swift run ez
```

## Testing

Due to a limitation in Swift Package Manager, the `UNIT_TEST` flag must be passed to the compiler for tests to use test-specific files and avoid interfering with your real configuration. Use the provided script to run tests:

```sh
./run-test.sh
```

Or pass additional arguments to filter tests:

```sh
./run-test.sh --filter EzTests.testScopeGetURL
```

This script runs:

```
swift test -Xswiftc -DUNIT_TEST
```

**Do not use `swift test` directly** unless you also pass the `-Xswiftc -DUNIT_TEST` flag, or tests may read/write your real alias files.

## Code Coverage

To run tests and generate a code coverage report, use the provided script:

```sh
./run-test-coverage.sh
```

This will:
- Run tests with coverage enabled and the UNIT_TEST flag
- Print a summary of code coverage (lines, functions, regions) for each file

You can also generate a detailed HTML report with:

```sh
llvm-cov show .build/debug/ezcliPackageTests.xctest/Contents/MacOS/ezcliPackageTests \
  -instr-profile $(swift test --show-codecov-path | tail -n 1) \
  -format=html -output-dir=coverage
```

Then open `coverage/index.html` in your browser to explore line-by-line coverage.

**Note:** Code coverage is only accurate when running tests with the UNIT_TEST flag and coverage enabled.

## Project Structure

- `ezcli/` - Source code
- `test/` - Unit tests
- `run-test.sh` - Script to run tests with the correct flags

## Requirements
- macOS 15.0+
- Swift 6.0+
- Xcode 16.4+

## License
MIT 

## Disclaimer

This software is provided under the MIT License. It is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

No support or maintenance is guaranteed. Use at your own risk. 

## Xcode Project Setup

If you wish to build this project for device or distribution, you must set your own Apple Development Team in the Xcode project settings. This project does not include a default team ID for privacy reasons. 

## Aliases

Aliases are stored in a JSON file (.ez_cli.json) within each directory, allowing for context-specific command sets. Local aliases take precedence when names conflict. To clear all aliases, delete the .ez_cli.json file in the relevant directory.

**Note:** Global alias support is currently disabled due to safety concerns. Only local aliases are supported. This may be revisited in a future release if a safe implementation is possible. 