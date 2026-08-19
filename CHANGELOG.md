# Changelog

All notable changes to ez are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries before 1.3.0 are reconstructed from commit history and are less detailed
than the releases that follow.

## [1.3.0] — 2026-08-19

### Added

- **`ez stats` — run history and timing trends.** Every alias run is recorded in a
  local SQLite database at `~/.ez/runs.db` (or `$EZCLI_HOME/runs.db`), scoped per
  directory.

  ```sh
  ez stats            # every alias with history here: success rate, median duration, trend
  ez stats deploy     # last 20 runs plus min / median / p90 / max and a trend
  ez stats deploy -v  # also show the machine each run was recorded on
  ```

  Only the alias definition is recorded — arguments and resolved secrets are never
  written to disk. Nothing is sent anywhere; delete the files to clear all history.

- **Outlier notes on finished runs.** A run meaningfully faster or slower than its own
  median appends a note to its timing line: `↑ 63% slower than median 9.1 s`. Runs
  within the normal range print exactly as before.

- **Machine context per run.** Hardware model, CPU, core counts, RAM, macOS version,
  a locally generated random machine ID, and a runs-since-boot counter are recorded
  alongside each run, so a timing series can be read in context later. Nothing is
  derived from your hostname or username.

### Changed

- **Exit codes propagate.** `ez <alias>` exits with the code of the command it ran, so
  `ez test && ez deploy` works. Parallel aliases report the first non-zero in command
  order. A child killed by a signal gives `128 + signal`; a failed spawn gives `126`.

- **ez's own errors exit 1 instead of 0.** Unknown alias, missing argument, and
  unreadable secret previously reported success.

- **Secrets are passed to commands through the environment, not argv,** so resolved
  values no longer appear in `ps`. A `{EZ_*}` placeholder written inside single quotes
  in a stored command now stays literal:

  ```sh
  ez add deploy 'curl -H "Authorization: {EZ_API_KEY}" https://api.example.com'   # works
  ez add deploy "curl -H 'Authorization: {EZ_API_KEY}' https://api.example.com"   # no longer expands
  ```

- **`stats` is a reserved alias name.** An existing alias named `stats` is permanently
  shadowed by the built-in; ez prints a note pointing at `ez remove stats`.

- The alias file is written atomically, so an interrupted write can no longer truncate
  `.ez_cli.json`.

### Deprecated

- **`ez add-secret --value <secret>`** — leaves the secret in shell history and `ps`.
  It still works and prints a warning, and will be removed in a future release.

  ```sh
  ez add-secret --key EZ_API_KEY                     # hidden prompt on a TTY
  pbpaste | ez add-secret --key EZ_API_KEY --force   # or pipe from any secret store
  ```

### Fixed

- Aliases failed in builds from source: under Swift 6.3 the entry point stopped routing
  alias names, so every `ez <alias>` exited with `Unexpected argument`.
- Ctrl+C now reaches parallel children. Commands started with `-p` inherited a blocked
  signal mask and ignored SIGINT/SIGTERM.
- Gapped placeholders: an alias using `{1}` and `{4}` counted one expected argument,
  skipped validation, and left `{4}` to the shell. All indices up to `{99}` are now
  found, and no argument is both substituted and re-appended.

### Internal

- swift-argument-parser 1.6.1 → 1.8.2.
- Acceptance tests extended to cover run history, exit codes, secrets, and signals.

## [1.2.2] — 2026-03-29

### Fixed

- Arguments substituted into `{1}`, `{2}` … placeholders were not shell-escaped, so an
  argument containing spaces or shell metacharacters was split or interpreted by the
  shell instead of being passed through intact.

## [1.2.0] — 2026-02-12

### Added

- **Secrets in Apple Keychain.** `ez add-secret` / `ez remove-secret` store and delete
  values referenced from aliases as `{EZ_*}` placeholders and resolved at run time.
- **Parameterized aliases.** `{1}`, `{2}` … placeholders are substituted with the
  arguments given to the alias.
- **Extra argument overflow.** Arguments beyond the highest placeholder are appended to
  the end of the command, so `ez gs pop` runs `git stash pop`.

## [1.0.4] — 2026-01-24

Version bump only; no user-facing changes.

## [1.0.3] — 2026-01-24

Version bump only; no user-facing changes.

## [1.0.2] — 2026-01-24

### Added

- **Full TTY passthrough**, so interactive commands like `vim`, `less` and `ssh` behave
  as if typed directly.
- **zsh tab completion** for locally defined aliases.
- Automated and interactive acceptance test suites.
- MIT license.

## [0.7.6] — 2025-07-25

Initial release. Project-scoped aliases stored in a per-directory `.ez_cli.json`, with
`ez add`, `ez remove`, `ez list`, sequential and parallel (`-p`) execution.

[1.3.0]: https://github.com/urtti/ez/releases/tag/1.3.0
[1.2.2]: https://github.com/urtti/ez/releases/tag/1.2.2
[1.2.0]: https://github.com/urtti/ez/releases/tag/1.2.0
[1.0.4]: https://github.com/urtti/ez/releases/tag/v1.0.4
[1.0.3]: https://github.com/urtti/ez/releases/tag/v1.0.3
[1.0.2]: https://github.com/urtti/ez/releases/tag/v1.0.2
[0.7.6]: https://github.com/urtti/ez/releases/tag/v0.7.6
