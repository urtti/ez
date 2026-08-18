# ez CLI — Development Guide

## What is ez?

A macOS CLI tool that stores terminal commands as short aliases. Aliases are stored per-directory in `.ez_cli.json` files. Built with Swift 6 and swift-argument-parser.

## Build & Test

```bash
swift build                  # Debug build → .build/debug/ez
swift build -c release       # Release build → .build/release/ez
./acceptance-test.sh         # Run all automated tests (builds first)
./acceptance-test-interactive.sh  # Manual tests for TTY/interactive features
```

**Toolchain:** `Package.swift` declares `.macOS(.v15)`, which the CommandLineTools
PackageDescription cannot resolve (`reference to member 'v15' cannot be resolved`).
If `xcode-select -p` points at CommandLineTools, prefix builds and test runs with
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`, or switch the
active toolchain with `xcode-select -s`.

## Testing

All testing is done via `acceptance-test.sh` — there are no Swift XCTest files. The script builds the binary, runs it in an isolated temp directory, and asserts on output.

**Running tests:** `./acceptance-test.sh`

**How tests work:**
- The script defines an `ez()` wrapper that calls the built binary and captures stdout+stderr
- Helper functions: `assert_contains` (grep match), `assert_equals` (exact match), `assert_exit_code`
- Tests run in a fresh temp directory (cleaned up on exit via trap); `EZCLI_HOME` points into it so run history never lands in the real `~/.ez`
- Pass/fail counts are tracked; script exits 1 if any test fails
- The Keychain is **not** isolated (`KeychainManager.service` is always `com.urtti.ez`), so tests must never use a key a real user might hold — never a plausible name like `EZ_TEST`, and never a documented example key like `EZ_API_KEY`. Both suites use a dedicated canary key that no real user would have (`EZ_ACCEPTANCE_TEST_CANARY` automated, `EZ_INTERACTIVE_TEST_CANARY` interactive), written with `--force`, and each script's trap deletes it — so aborting midway still cleans up. The automated one also skips itself if the keychain is unavailable

**Adding new tests:** Append to `acceptance-test.sh` before the `# Summary` section. Follow the existing pattern:
```bash
ez add myalias "echo something {1}"
output=$(ez myalias arg1)
assert_contains "$output" "something arg1" "description of what is being tested"
```

**Test categories covered:** version/help, add/remove/list, alias execution, parallel mode, shell expansion, sequential commands, parameter substitution, extra argument overflow, secret placeholders, add-secret validation, error cases, run history (recording, secret safety, summary and trend).

There is also `acceptance-test-interactive.sh` for manual verification of TTY features (vim, less, signal handling) that can't be automated.

## Project Structure

```
ezcli/
  ez.swift              # Entry point, signal handling, command routing
  Alias.swift           # Alias model: commands, execution type, parameter substitution, secrets
  AliasCollection.swift # Alias storage: JSON persistence, add/remove/lookup
  Keychain.swift        # KeychainManager: Apple Keychain read/write/delete via Security framework
  Scope.swift           # Local vs global scope, file paths, test isolation
  SystemActions.swift   # Process execution via posix_spawn, parallel via TaskGroup
  TerminalOutput.swift  # ANSI formatting, timing, error output
  Telemetry/
    TelemetryPaths.swift # Telemetry root ($EZCLI_HOME or ~/.ez) and DB path
    RunRecord.swift      # One recorded alias run
    RunSummary.swift     # Count/min/median/p90/max plus RunTrend over successful runs
    RunStore.swift       # actor RunStore: sqlite3 connection, schema migration, insert/query
  commands/
    Add.swift           # `ez add` — creates aliases (-p for parallel, -d for description)
    AddSecret.swift     # `ez add-secret` — stores secrets in Keychain
    Remove.swift        # `ez remove` — deletes aliases
    RemoveSecret.swift  # `ez remove-secret` — removes secrets from Keychain
    List.swift          # `ez list` — shows aliases (-v for verbose)
    Stats.swift         # `ez stats [alias]` — run history, summary and trend for this directory
    Execute.swift       # Stub; actual execution is in ez.swift
    InstallCompletions.swift    # Adds zsh completions to ~/.zshrc
    UninstallCompletions.swift  # Removes zsh completions from ~/.zshrc
```

## Key Architecture

- **Process execution** uses `posix_spawn` directly (not Foundation's `Process`) with TTY passthrough via inherited file descriptors. This enables interactive commands (vim, less, ssh).
- **Signal forwarding**: SIGINT, SIGTERM, SIGQUIT, SIGTSTP, SIGCONT are forwarded to child processes via a `@MainActor` PID set.
- **Parallel mode** (`-p` flag) spawns commands concurrently using Swift `TaskGroup`.
- **Command routing**: Subcommands (add/remove/list) go through ArgumentParser. Alias execution is custom-routed in `ez.swift main()`.
- **`Ez.main()` must stay `static func main() async`** — exactly the signature `AsyncParsableCommand` supplies in its extension. Adding `throws` (or otherwise changing it) means it no longer shadows the library's version, so `@main` silently uses ArgumentParser's own entry point, which knows nothing about aliases: every `ez <alias>` then fails with `Error: Unexpected argument '<alias>'`. Verified to fail this way on swift-argument-parser 1.6.1 and 1.8.2 alike. No test catches the signature itself; the alias-execution tests catch the symptom.
- **Shell**: All commands execute via `/bin/zsh -c`.
- **Exit codes**: `ez <alias>` exits with the code of the work it drove, so `ez test && deploy` behaves. Sequential aliases propagate the command's code; parallel aliases report the first non-zero in command order (matching what is recorded). A child killed by a signal gives `128 + signal`; a failed spawn gives 126. ez's own error paths — unknown alias, missing arguments, unreadable secret — exit **1** (generic failure; codes ≥126 are reserved for describing the child's fate).

## Alias Storage Format

```json
{
  "aliases": {
    "deploy": {
      "executionType": "sequential",
      "commands": ["git push origin main && ssh server deploy"],
      "description": "Deploy to production"
    }
  }
}
```

- `executionType`: `"sequential"` (default) or `"parallel"` (`-p` flag)
- `commands`: Array of command strings. Sequential joins with space; parallel runs concurrently.
- `description`: Optional, added via `-d` flag.

## Parameter Substitution

Aliases support `{1}`, `{2}`, ... `{n}` placeholders that are replaced at runtime:

```bash
ez add tag 'git tag -a {1} -m "Release {1}"'
ez tag v2.0.0  # → git tag -a v2.0.0 -m "Release v2.0.0"
```

- Implemented in `Alias.substituting(arguments:)` and `Alias.maxPlaceholderIndex`
- Validated in `ez.swift` before execution — missing args produce an error message

**Extra argument overflow:** Any arguments beyond the highest placeholder index are appended to the end of the last command. This works for both parameterized and non-parameterized aliases:

```bash
# Non-parameterized — all args appended
ez add gs "git stash"
ez gs pop             # → git stash pop

# Parameterized — extra args appended after substitution
ez add greet 'echo hello {1}'
ez greet world foo bar  # → echo hello world foo bar
```

- Implemented in `Alias.appending(extraArguments:)` — shell-escapes each extra arg (preserving spaces via single-quoting) and appends to the last command string
- `ez.swift` splits args: first N go to placeholder substitution, the rest go to `appending(extraArguments:)`

## Scope System

- **Local**: `.ez_cli.json` in the current directory (fully functional)
- **Global**: `~/.ez_cli_global.json` (infrastructure exists in `Scope.swift` but not integrated into commands yet)
- **Test isolation**: When `EZCLI_UNIT_TEST=1`, files redirect to `/tmp/ez_cli_tests/`

## Secrets

Aliases can reference secrets stored in Apple Keychain using `{EZ_*}` placeholders:

```bash
# Store a secret
ez add-secret --key EZ_API_KEY --value sk-abc123

# Use it in an alias
ez add deploy 'curl -H "Authorization: {EZ_API_KEY}" https://api.example.com/deploy'
```

**How it works:**
- `ez add-secret --key EZ_KEY --value val` stores a secret in macOS Keychain (service: `com.urtti.ez`). Use `--force` to overwrite.
- `ez remove-secret EZ_KEY` deletes a secret from Keychain.
- At execution time, `Alias.secretKeys` scans commands for `{EZ_*}` patterns, then `ez.swift` reads each key from Keychain. Values are passed to the child **via its environment** (`posix_spawn` `envp`, built in `SystemActions.makeSpawnEnvironment`), and `Alias.referencingSecretsFromEnvironment(_:)` rewrites each `{EZ_FOO}` to `"$EZ_FOO"` — so resolved values never appear in the child's argv, keeping them out of `ps`. An inherited env var with the same name is dropped so the Keychain value wins.
- Because `"$EZ_FOO"` doesn't expand inside single quotes, a placeholder single-quoted *within* the stored command stays literal. All documented examples put placeholders in double quotes, which work as before.
- Secret resolution happens **after** the "Executing:" line is printed, so secret values never appear in terminal output.
- Key names must match `^EZ_[A-Z0-9_]+$` — validated both in `AddSecret` and in `Alias.secretKeys`.
- Keychain storage uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security.
- Errors (missing secret, auth failure) are reported and execution is aborted.

**Implementation:** `Keychain.swift` (`KeychainManager` enum) wraps the Security framework. `AddSecret.swift` and `RemoveSecret.swift` are the subcommands.

## Run History

Every alias execution records one row in a local SQLite database — `$EZCLI_HOME/runs.db` if set, otherwise `~/.ez/runs.db`. `ez stats <alias>` prints the last 20 runs plus a summary block for the current directory; bare `ez stats` lists every alias with history there, laid out like `ez list`.

- `Telemetry/TelemetryPaths.swift` resolves the root; `acceptance-test.sh` exports `EZCLI_HOME` to a per-run temp dir so tests never touch real history.
- `Telemetry/RunStore.swift` is the only file using the sqlite3 C API — an actor owning one connection, with WAL + `busy_timeout=2000` for concurrent `ez` processes, and migrations gated on `PRAGMA user_version`. Writes that fail are reported via `printError` and swallowed; telemetry must never fail the user's command.
- Schema v1 — `runs`: `cwd`, `alias_name`, `command_template`, `execution_type`, `exit_code`, `duration_ms`, `started_at`. Queries always scope by `cwd`, since aliases are per-directory.
- `command_template` is the **pre-substitution** alias definition (`alias.commandTemplate`), so arguments and resolved `{EZ_*}` secrets are never written to disk. Parallel commands join with `" ;; "` there, so a recorded template never reads as a shell pipeline.
- One row per invocation, including parallel aliases: `duration_ms` is total wall time measured with `ContinuousClock`, `exit_code` is the first non-zero **in command order**. Exit status is decoded from `waitpid` (signal → `128 + signal`); a run whose exit code can't be determined is not recorded at all.
- Parallel mode prints the pre-secret `displayCommands`, so resolved secrets never reach the terminal either.
- Recency ordering uses `id`, not `started_at`, so insertion order survives a backward clock step.
- `Telemetry/RunSummary.swift` computes count/min/median/p90/max and the trend over `exit_code = 0` rows only, so a failed or interrupted fast run never drags the median. Median averages the middle two on an even sample count; p90 is nearest-rank.
- Trend is the median of the most recent 5 successful runs against the previous 5. Fewer than 10 prints "not enough data"; a change under 15% reads as "steady", so it doesn't cry wolf; a zero previous median prints "no baseline" rather than claiming steadiness.
- **Per-run outlier notes** (`RunOutlier` in `RunSummary.swift`): a finished run appends `↑ 63% slower than median 9.1 s` to its timing line, but *only* when it is worth saying — normal output is untouched otherwise. Requires ≥5 prior successful runs, the run to have succeeded, and the change to exceed the same 15% threshold. The baseline is read **before** the run is recorded so it never pollutes its own comparison. The `OUTLIER_MIN_MS` (500 ms) gate tests `max(thisRun, baseline)`, not the run alone — otherwise an alias that drops from 10 s to 0.2 s would be silenced for becoming fast, which is exactly the speedup worth reporting. Parallel aliases print a `total` line only when there is a note, since sub-jobs already print their own timings.
- Outlier notes catch **outliers**; `ez stats` catches **drift**. A rolling median moves with slow drift, so a run creeping up over weeks never trips the per-run note — the two are complementary.

## Protected Keywords

Alias names `add`, `remove`, `list`, `stats`, `add-secret`, and `remove-secret` are reserved and cannot be used (`PROTECTED_KEYWORDS` in `Add.swift`). An alias can still hold a reserved name it acquired *before* the keyword shipped — it is then permanently shadowed, so running that keyword prints a note (to stderr, from the router in `ez.swift`) recommending `ez remove <name>` or re-adding under a different name. `Remove` deliberately has no keyword guard, so removing a shadowed alias works.

## Release Process

`./release.sh <version>` handles the full release: updates version in `ez.swift`, builds, creates GitHub release with tarball, and updates the homebrew tap at `../homebrew-ez`. The codesign identity is never hard-coded: the script reads `$EZ_CODESIGN_IDENTITY`, falling back to the `EZ_CODESIGN_IDENTITY` Keychain secret (`ez add-secret --key EZ_CODESIGN_IDENTITY --value "Apple Development: ..."`) — the same secret the `install-local` alias in `.ez_cli.json` uses.

Version is stored as `private let VERSION` in `ez.swift`. Do **not** hard-code a `v` prefix in the printed version — `release.sh` writes whatever it is given into `VERSION` (it even guards against a double `vv`), so `./release.sh v1.2.3` would print `vv1.2.3`. The acceptance test is deliberately prefix-agnostic.

**The release ships a prebuilt binary, not source.** `release.sh` copies `.build/release/ez` into the tarball and the formula just does `bin.install "ez"` — every user runs the artifact built on the release machine. Two consequences:

- **Avoid releasing from a beta toolchain / beta macOS.** A release build here produces `minos 15.0` and links only absolute-path system dylibs (verified), so it is more portable than it looks — but you cannot test it on the OS versions you claim to support, and a beta compiler's output would reach every user untested. Prefer a stable toolchain, ideally a GitHub Actions `macos-15` runner, which retires the question permanently.
- **The formula's `test do` block only runs `ez --version`.** That is exactly the test that passes while the binary is completely broken — the `@main` regression above left `--version` working perfectly while every alias failed. Worth strengthening it to add and run an alias.

## Skills

### /test
Run `./acceptance-test.sh` from the project root. If any tests fail, read the output and fix the issue.

### /build
Run `swift build` from the project root. If there are compilation errors, fix them.

## Dependencies

Only one: `swift-argument-parser` 1.8.2 (exact). Everything else (process management, JSON, formatting) is custom.
