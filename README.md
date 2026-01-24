# ez

A macOS CLI tool for project-specific command aliases. Define commands locally within project directories, making team workflows more efficient and discoverable.

![Demo](https://vhs.charm.sh/vhs-MNJIHYcWKivqHnrdoc14c.gif)

## Features

- **Project-scoped storage** - Aliases live in `.ez_cli.json` files at the directory level, keeping commands tethered to their respective projects
- **Safety through locality** - No global aliases means no accidental damage in a different directory
- **Team collaboration** - Commit the config file to version control so new team members get immediate access to established commands
- **Fast** - Built in Swift with zero third-party dependencies and instant startup times
- **Private** - Entirely offline with no telemetry or cloud connectivity
- **Interactive support** - Full terminal passthrough for interactive applications like vim and ssh
- **Shell integration** - zsh tab completion for command discovery
- **Built-in analytics** - Automatic runtime tracking logs command execution duration

## Installation

```sh
brew tap urtti/ez && brew install ez
```

## Usage

Add an alias:
```sh
ez add deploy "./scripts/deploy.sh --env prod"
```

Run an alias:
```sh
ez deploy
```

List all aliases:
```sh
ez list
```

Remove an alias:
```sh
ez remove deploy
```

Run multiple commands sequentially:
```sh
ez build && ez test && ez deploy
```

Run commands in parallel:
```sh
ez -p lint test
```

## How It Works

Aliases are stored in `.ez_cli.json` files within each directory. This keeps commands context-specific and prevents conflicts between projects. To clear all aliases in a directory, simply delete the `.ez_cli.json` file.

## Requirements

- macOS 15.0+

## Development

### Building

```sh
swift build
```

### Running from source

```sh
swift run ez
```

### Testing

Use the provided script to run tests with the correct flags:

```sh
./run-test.sh
```

Or filter specific tests:

```sh
./run-test.sh --filter EzTests.testScopeGetURL
```

**Note:** Do not use `swift test` directly. The `UNIT_TEST` flag must be passed to prevent tests from interfering with your real configuration:

```sh
swift test -Xswiftc -DUNIT_TEST
```

### Code Coverage

Generate a coverage report:

```sh
./run-test-coverage.sh
```

For a detailed HTML report:

```sh
llvm-cov show .build/debug/ezcliPackageTests.xctest/Contents/MacOS/ezcliPackageTests \
  -instr-profile $(swift test --show-codecov-path | tail -n 1) \
  -format=html -output-dir=coverage
```

### Project Structure

- `ezcli/` - Source code
- `test/` - Unit tests
- `run-test.sh` - Script to run tests with the correct flags

### Build Requirements

- Swift 6.0+
- Xcode 16.4+

### Xcode Setup

If building for device or distribution, set your own Apple Development Team in the Xcode project settings.

## License

MIT
