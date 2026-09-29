# ez — marketing plan ($0)

Ready-to-paste texts are in [copy.md](copy.md); the launch post is in
[blog-launch-post.md](blog-launch-post.md). **[CHECK]** marks something I
couldn't verify from here.

## Where it stands

- 9 stars, 0 forks, installed from a personal tap (`brew tap urtti/ez`).
  Nobody finds it because nothing points at it: no GitHub topics, no listing in
  any awesome-list or CLI directory, never posted anywhere developers read.
- The name is ungoogleable. "ez" alone will never rank, so every mention needs
  the same descriptive tail: **"ez — per-project command aliases for macOS"**.
- The product is genuinely differentiated; it's just not *said*. Today the
  README opens with "project-specific command aliases", which sounds like
  `alias` in a `.zshrc`.

## Positioning

**One line:** *Per-project command aliases for macOS — with Keychain secrets and
a timing history for every run.*

**The pitch in three beats**

1. `ez add deploy "…"` in a repo, then `ez deploy` — the alias lives in
   `.ez_cli.json` next to the code, so it can be committed and your team gets it.
2. `{EZ_API_KEY}` in an alias reads from the macOS Keychain and is passed via
   the environment — never in shell history, `ps`, or the terminal.
3. Every run is timed locally; `ez stats` tells you your test suite got 40%
   slower this week. Nothing leaves the machine.

**Honest comparison** (people will ask "why not just…")

| | ez | shell `alias` | Makefile / `just` | `npm run` | mise tasks |
|---|---|---|---|---|---|
| Per-directory, committable | ✅ | ❌ | ✅ | ✅ (JS only) | ✅ |
| Add from the command line in one line | ✅ | ✅ | ❌ edit a file | ❌ edit a file | ❌ edit a file |
| Keychain secrets, kept out of `ps` | ✅ | ❌ | ❌ | ❌ | ❌ (env / sops) |
| Run timing history + slowdown alerts | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cross-platform | ❌ macOS | ✅ | ✅ | ✅ | ✅ |
| Dependencies between tasks | ❌ | ❌ | ✅ | partial | ✅ |

Say plainly that `just`/`make` are better for build graphs; ez is for the
twenty one-liners you retype every week. Conceding that wins arguments on HN.

**Audience:** macOS developers who live in the terminal — especially the ones
juggling several repos with different deploy/test incantations, and anyone
who has pasted an API token into a command line.

## The plan — in order

### Step 0 — fix the storefront (1 hour, before any posting)

- [ ] **GitHub "About" box:** description, website and topics from copy.md § 1.
      Topics are how GitHub search and "explore" surface a repo.
- [ ] **Social preview image** (Settings → Social preview): a 1280×640 crop of
      a frame from `docs/demo.gif`, so links on HN/Mastodon/Slack show a picture.
- [ ] **README fix — the parallel example is wrong.** It says
      `ez -p lint test`, but `-p` is a flag on `add`
      (`ezcli/commands/Add.swift:13`); there is no top-level `-p`. Anyone who
      tries it from the README hits an error on their first try. Corrected
      text in copy.md § 2, with a new opening section. Say the word and I'll
      commit it.
- [ ] **Homebrew formula test** — CLAUDE.md already notes `test do` only runs
      `--version`. Not marketing, but a broken release after a front-page post
      would be the worst possible timing.

### Step 1 — get listed (1–2 evenings; every one of these is permanent traffic)

Open PRs with the exact lines in copy.md § 3. Read each repo's CONTRIBUTING
first; several require a minimum star count or age — skip those for now and
come back after Step 2.

- [ ] `agarrharr/awesome-cli-apps`
- [ ] `herrbischoff/awesome-macos-command-line`
- [ ] `matteocrippa/awesome-swift` (Command Line section)
- [ ] `jaywcjlove/awesome-mac` (Developer Tools → Command Line)
- [ ] `iCHAIT/awesome-macOS`
- [ ] **Terminal Trove** (terminaltrove.com → Submit a tool) — free
- [ ] **Console.dev** (console.dev → submit) — free weekly dev-tools newsletter
- [ ] **Swift Package Index** — add the repo (swiftpackageindex.com/add-a-package);
      gives a searchable page for Swift developers. **[CHECK: SPI lists
      executables fine, but needs a tagged semver release — you have 1.3.0]**

### Step 2 — launch (one day, Tue–Thu)

- [ ] Publish [blog-launch-post.md](blog-launch-post.md) on urtti.com/ez
      (or dev.to, cross-posted to urtti.com).
- [ ] **Show HN** at ~15:00–16:00 Finnish time (copy.md § 4). Link to the
      GitHub repo, not the blog. Stay for the first two hours and answer
      every comment — that's what keeps a Show HN on the front page.
- [ ] Same day: Mastodon/Bluesky thread (copy.md § 6).
- [ ] Next day: r/commandline, then r/swift two days later, then r/macprogramming
      (copy.md § 5). Different text each; never the same day.

### Step 3 — follow-through

- [ ] When stars pass **75**, submit to **homebrew-core** so it's
      `brew install ez` with no tap. Homebrew's notability bar is
      ≥75 stars or ≥30 forks/watchers **[CHECK current bar in Homebrew's
      "Acceptable Formulae" doc, and whether the name `ez` is free in core]**.
      This is the single biggest friction cut.
- [ ] Swift Forums → Community Showcase post (copy.md § 7).
- [ ] Newsletters, free submissions: iOS Dev Weekly, Swift Weekly Brief,
      Changelog News (changelog.com/news/submit), Hacker Newsletter picks from HN.
- [ ] Answer existing questions: Stack Overflow / Reddit threads about
      "project-specific aliases", "per-directory aliases zsh", "store API key
      for curl command mac" — only where ez actually answers, with disclosure
      (template copy.md § 8).
- [ ] Cross-promote: "Also by Urtti Apps: Big Weather" line in the README footer.

## What to measure

- GitHub → Insights → Traffic: views, unique visitors, referrers (shows which
  post worked).
- The existing `downloads` alias in `.ez_cli.json` prints release asset
  download counts — run it before and after each step and note the date.
- Stars per week.

## What not to do

- Don't buy stars or join upvote rings — HN and GitHub both detect it and it
  kills the account's credibility.
- Don't post the same text to five subreddits in one day; it reads as spam and
  mods remove it.
- Don't call parallel mode a headline feature while its own help text says
  "Experimental state".
