# ez — ready-to-paste copy

Links: repo `https://github.com/urtti/ez` · site `https://urtti.com/ez`

---

## 1. GitHub "About" box (repo page → ⚙ next to About)

**Description** (350 max):
```
Per-project command aliases for macOS. Store the commands you retype in .ez_cli.json next to your code, keep API keys in the Keychain, and see when a command gets slower. Swift, no network calls.
```

**Website:** `https://urtti.com/ez`

**Topics** (paste one at a time):
```
cli macos swift aliases command-line developer-tools productivity terminal zsh keychain task-runner homebrew
```

---

## 2. README — corrected parallel example and a stronger opening

**Replace** the "Run commands in parallel" block (currently `ez -p lint test`,
which errors — `-p` belongs to `add`) with:

```markdown
Run several commands in parallel under one alias (experimental):
```sh
ez add -p checks "npm run lint" "npm test"
ez checks
```
```

**Replace** the first paragraph under `# ez` with:

```markdown
**Per-project command aliases for macOS.** Save the commands you keep retyping
in each repo — deploys, test runs, the curl you always look up — as short
aliases that live next to the code:

```sh
ez add deploy './scripts/deploy.sh --env prod'
ez deploy
```

- **Committable.** Aliases live in `.ez_cli.json`; commit it and your team has them too.
- **Secrets stay secret.** `{EZ_API_KEY}` reads from the macOS Keychain and never appears in shell history, `ps`, or the terminal.
- **Knows when things get slower.** Every run is timed locally; `ez stats` shows medians and trends, and a run 60% slower than usual says so.
- **Private.** No network calls, ever.
```

**Add** a short "Why not just…" section above `## Installation`:

```markdown
## Why not just…

- **…shell aliases?** Those are global. `ez test` means something different in each repo, and a teammate gets it by cloning.
- **…make / just?** Use them for build graphs. ez is for the twenty one-liners that never deserved a Makefile target — and you add one without opening an editor.
- **…npm scripts?** Not every repo is a JS repo, and npm won't keep your API key out of `ps`.
```

---

## 3. Awesome-list entries (one line each; match each list's format)

**awesome-cli-apps** (section: Development or Productivity):
```
- [ez](https://github.com/urtti/ez) - Per-project command aliases for macOS with Keychain secrets and run-time stats.
```

**awesome-macos-command-line** (section: Developer / Productivity):
```
### ez

Save per-project commands as short aliases in a committable `.ez_cli.json`, with secrets from the Keychain.

```bash
ez add deploy './scripts/deploy.sh --env prod'
ez deploy
```

[ez](https://github.com/urtti/ez)
```

**awesome-swift** (Command Line section):
```
- [ez](https://github.com/urtti/ez) - Per-project command aliases for macOS with Keychain-backed secrets. :large_orange_diamond:
```
*(`:large_orange_diamond:` is awesome-swift's marker for Swift 5+/6 — check the legend.)*

**awesome-mac** (Developer Tools → Command Line Tools):
```
* [ez](https://github.com/urtti/ez) - Per-project command aliases with Keychain secrets and run timing. [![Open-Source Software][OSS Icon]](https://github.com/urtti/ez) ![Freeware][Freeware Icon]
```

**PR title** (all): `Add ez (per-project command aliases for macOS)`
**PR body:**
```
Adds ez, an MIT-licensed Swift CLI for per-project command aliases on macOS: aliases are stored in a committable .ez_cli.json, secrets come from the Keychain, and every run is timed locally. Installed via Homebrew. I'm the author.
```

**Terminal Trove / Console.dev form:**
- Name: ez
- Tagline: `Per-project command aliases for macOS, with Keychain secrets and run timing.`
- Description: use the README opening from § 2.
- Language: Swift · License: MIT · Platform: macOS · Install: `brew tap urtti/ez && brew install ez`
- Media: `docs/demo.gif`

---

## 4. Show HN

**Title** (80 max):
```
Show HN: ez – per-project command aliases for macOS, with Keychain secrets
```

**URL:** `https://github.com/urtti/ez`

**First comment (post immediately after submitting):**
```
Hi HN, I'm Tommi. I built ez because every repo I work in has five or six commands I retype from memory or shell history — the deploy with the right flags, the curl with an API token, the test run with the one env var.

ez stores them per directory in a .ez_cli.json:

  ez add deploy './scripts/deploy.sh --env prod'
  ez add tag 'git tag -a {1} -m "Release {1}"'
  ez tag v2.0.0

A few things I cared about:

- Secrets: `{EZ_API_KEY}` in an alias is read from the macOS Keychain at run time and handed to the child through its environment, so the value never shows up in argv / ps, shell history, or ez's own output.
- Timing: every run is recorded locally in SQLite. `ez stats` shows median, p90 and a trend per alias, and a single run that's much slower than its own median gets a one-line note. I wanted to notice the test suite creeping up before it doubled.
- Interactive commands work (vim, ssh, less): it spawns with posix_spawn and passes the TTY straight through, and forwards signals — including to parallel children, which turned out to need an explicit empty signal mask.
- No network calls at all.

What it isn't: a build system. If you need task dependencies, make or just are better. It's also macOS-only, because of the Keychain.

Install: brew tap urtti/ez && brew install ez

I'd especially like to hear what would stop you from committing a .ez_cli.json to a shared repo.
```

**Prepared answers for likely comments**

- *"Why not just / make / direnv / mise?"*
  ```
  All good tools — if you already have a justfile, keep it. ez is for the commands that never made it into one: you add them in one line without opening an editor, and they can pull secrets from the Keychain. direnv is complementary: it sets env, ez runs commands.
  ```
- *"Running commands from a cloned repo's JSON is a security risk."*
  ```
  Agreed, same as a Makefile or npm scripts — the README says to review .ez_cli.json before running aliases from repos you don't trust. `ez list` shows every alias's full command before you run it.
  ```
- *"Linux support?"*
  ```
  Secrets use the macOS Keychain and the process code uses Darwin APIs, so not today. If there's interest, libsecret on Linux is the obvious route — would you use it?
  ```
- *"Why record telemetry?"*
  ```
  It's local only — a SQLite file in ~/.ez, never sent anywhere, and it stores the alias definition, not your arguments or secret values. Delete the folder to clear it.
  ```

---

## 5. Reddit

### r/commandline
**Title:**
```
ez: per-directory command aliases (macOS) — secrets from the Keychain, and it tells you when a command got slower
```
**Body:**
```
I kept retyping the same long commands per project, so I made a small tool for it. Aliases live in `.ez_cli.json` in the directory, so they can be committed:

    ez add deploy './scripts/deploy.sh --env prod'
    ez add tag 'git tag -a {1} -m "Release {1}"'
    ez tag v2.0.0
    ez stats          # success rate, median duration, trend per alias

`{EZ_API_KEY}` placeholders read from the Keychain and never show up in ps or history. Interactive commands (vim, ssh) work. No network calls. MIT, Swift, installed via Homebrew.

https://github.com/urtti/ez — I'm the author; feedback welcome, especially on what's missing.
```

### r/swift (two days later)
**Title:**
```
Lessons from a Swift 6 CLI: posix_spawn, async-signal-safe signal forwarding, and an @main gotcha
```
**Body:**
```
I've been building ez, a macOS CLI for per-project command aliases, in Swift 6 with swift-argument-parser. A few things that bit me, in case they save someone time:

1. If you override `main()` on an AsyncParsableCommand, the signature must be exactly `static func main() async`. Add `throws` and it no longer shadows the library's version — @main silently uses ArgumentParser's own entry point instead. My custom routing vanished and every alias failed with "Unexpected argument". `--version` kept working, so the Homebrew test passed.
2. Signal handlers can't touch Swift collections (allocation, locks). Child PIDs live in a fixed table of `Atomic<pid_t>` slots, touched in main() before handlers are installed so its lazy init never happens inside a handler.
3. Children spawned from Swift-concurrency worker threads inherit those threads' blocked signal mask. Parallel children silently ignored Ctrl+C until I set `POSIX_SPAWN_SETSIGMASK` with an empty mask.

Source: https://github.com/urtti/ez (MIT)
```

### r/macprogramming / r/MacOS (later)
Reuse the r/commandline body with the title:
```
I made a small Mac CLI that keeps per-project commands and reads API keys from the Keychain
```

---

## 6. Mastodon / Bluesky thread (each < 300 chars; attach demo.gif to 1/)

1/
```
ez: per-project command aliases for macOS 🐘

ez add deploy './scripts/deploy.sh --env prod'
ez deploy

Aliases live in .ez_cli.json next to your code — commit it and your team has them.

https://github.com/urtti/ez
#macOS #CLI #Swift
```
2/
```
API keys come from the Keychain: put {EZ_API_KEY} in an alias and the value reaches the command through its environment — never in shell history, ps, or the terminal.
```
3/
```
And every run is timed locally. `ez stats` shows the median and trend per alias, and a run that's much slower than usual says so:

↑ 63% slower than median 9.1 s

No network calls. MIT. brew tap urtti/ez && brew install ez
```

---

## 7. Swift Forums — Community Showcase

**Title:** `ez — per-project command aliases for macOS, in Swift 6`

**Body:** the r/swift body from § 5, prefixed with:
```
I'd like to share ez, an MIT-licensed command-line tool built with Swift 6 and swift-argument-parser.
```

---

## 8. Reply template for existing questions

```
Disclosure: I wrote a tool for exactly this — ez (https://github.com/urtti/ez, macOS). `ez add <name> '<command>'` stores it in a .ez_cli.json in that directory, so it's per-project and can be committed; secrets can come from the Keychain with {EZ_KEY} placeholders. If you'd rather stay dependency-free, [the plain-shell answer to their question] works too.
```
