# ez

A macOS CLI tool for project-specific command aliases. Define commands locally within project directories, making team workflows more efficient and discoverable.

![Demo](https://vhs.charm.sh/vhs-MNJIHYcWKivqHnrdoc14c.gif)

## Features

- **Project-scoped storage** - Aliases live in `.ez_cli.json` files at the directory level, keeping commands tethered to their respective projects
- **Safety through locality** - No global aliases means no accidental damage in a different directory
- **Team collaboration** - Commit the config file to version control so new team members get immediate access to established commands. As with a `Makefile` or `npm run`, running an alias from a cloned repo runs whatever commands that repo's authors defined — review `.ez_cli.json` before running aliases from sources you don't trust
- **Fast** - Built in Swift with instant startup times and no third-party dependencies — the only package used is Apple's own swift-argument-parser
- **Secrets management** - Store API keys and tokens in Apple Keychain, reference them in aliases without exposing values in terminal output or the process table
- **Private** - Makes no network calls; run history is recorded locally in `~/.ez/runs.db` and never leaves your machine
- **Interactive support** - Full terminal passthrough for interactive applications like vim and ssh
- **Shell integration** - zsh tab completion for command discovery
- **Built-in analytics** - Local runtime tracking; `ez stats` shows per-alias duration history and trends

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

Parameterized aliases with `{1}`, `{2}`, ... placeholders:
```sh
ez add tag 'git tag -a {1} -m "Release {1}"'
ez tag v2.0.0  # → git tag -a v2.0.0 -m "Release v2.0.0"
```

Extra arguments are automatically appended to the end of the command:
```sh
ez add gs "git stash"
ez gs pop              # → git stash pop

ez add greet 'echo hello {1}'
ez greet world a b     # → echo hello world a b
```

Store secrets in Apple Keychain and reference them in aliases:
```sh
ez add-secret --key EZ_API_KEY --value sk-abc123
ez add deploy 'curl -H "Authorization: {EZ_API_KEY}" https://api.example.com/deploy'
ez deploy  # secret is injected at runtime, never shown in terminal output
```

Remove a secret:
```sh
ez remove-secret EZ_API_KEY
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

Every alias run is also recorded in a local SQLite database at `~/.ez/runs.db` (override the location with `$EZCLI_HOME`): working directory, alias name, the command *template* — never substituted arguments or secret values — exit code, duration, and timestamp. Nothing is ever sent anywhere; delete the file to clear all history.

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

Run the acceptance test suite:

```sh
./acceptance-test.sh
```

The script builds the binary, runs it in an isolated temp directory, and asserts on output — nothing touches your real aliases, run history, or (aside from a dedicated canary key it cleans up) your Keychain.

Interactive TTY features (vim, less, signal handling) can't be automated; verify those manually with:

```sh
./acceptance-test-interactive.sh
```

### Project Structure

- `ezcli/` - Source code
- `acceptance-test.sh` - Automated test suite
- `acceptance-test-interactive.sh` - Manual tests for interactive/TTY features

### Build Requirements

- Swift 6.0+
- Xcode 16.4+

### Xcode Setup

If building for device or distribution, set your own Apple Development Team in the Xcode project settings.

## License

MIT
