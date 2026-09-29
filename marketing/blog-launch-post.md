# The commands I kept retyping

*Launch post for urtti.com/ez or dev.to. ~800 words. Every behaviour described
is in the README/CHANGELOG for 1.3.0.*

---

Every repository I work in has five or six commands that live only in my shell
history. The deploy with the right flags. The curl with an API token pasted in
the middle. The test run that needs one environment variable set. I retype
them from memory, get one flag wrong, and scroll back through `Ctrl-R` to find
the version that worked last month.

Shell aliases don't fix this: they're global, so `test` can only mean one
thing. A Makefile fixes it, but nobody opens an editor to add a target for a
one-liner. So I wrote **ez**.

## One line to add, one word to run

```sh
ez add deploy './scripts/deploy.sh --env prod'
ez deploy
```

The alias is stored in `.ez_cli.json` in the current directory. `cd` into
another project and `ez deploy` means that project's deploy. Commit the file
and everyone on the team has the same commands — the way a Makefile or
`npm run` works, without either.

Arguments work the way you'd hope:

```sh
ez add tag 'git tag -a {1} -m "Release {1}"'
ez tag v2.0.0          # git tag -a v2.0.0 -m "Release v2.0.0"

ez add gs 'git stash'
ez gs pop              # extra arguments are appended: git stash pop
```

Substituted arguments are shell-escaped, so a value with spaces stays one
argument. `ez list` shows everything in the directory; `ez` exits with the
command's own exit code, so `ez test && ez deploy` does what it says.

## Secrets that stay out of your history

The command I hated most was the one with a token in it. Now it's:

```sh
ez add-secret --key EZ_API_KEY      # hidden prompt, stored in the Keychain
ez add deploy 'curl -H "Authorization: {EZ_API_KEY}" https://api.example.com/deploy'
```

At run time ez reads the value from the macOS Keychain and hands it to the
command through its environment, not its arguments. So it never appears in
your shell history, in `ps`, in ez's own output — or in the `.ez_cli.json` you
committed. In scripts, pipe it in: `op read … | ez add-secret --key EZ_API_KEY --force`.

## It notices when things get slower

This is the part I didn't plan. Every run is recorded in a local SQLite file:
the alias, how long it took, whether it succeeded. Not your arguments, not
your secrets — the alias definition only.

```sh
ez stats          # every alias here: success rate, median duration, trend
ez stats test     # last 20 runs, min / median / p90 / max, and a trend
```

The trend compares the median of your last five successful runs with the five
before. Under a 15% change it just says "steady", so it doesn't cry wolf.

And when a single run is well outside its own normal, the timing line says so:

```
↑ 63% slower than median 9.1 s
```

Otherwise the output is exactly as before. The two catch different things: the
note catches an outlier today; `ez stats` catches the test suite that crept up
a little every week and never tripped anything.

Nothing is sent anywhere. ez makes no network calls at all.

## Things that had to be right

A command runner is only useful if it gets out of the way:

- **Interactive commands work.** vim, less, ssh — ez spawns with `posix_spawn`
  and passes your terminal straight through.
- **Ctrl-C reaches the command**, including every child of a parallel alias.
  (Children spawned from Swift's concurrency threads inherit a blocked signal
  mask; ez spawns them with an empty one.)
- **It starts instantly.** It's a native Swift binary whose only dependency is
  Apple's swift-argument-parser.

## What it isn't

It's not a build system: if your tasks depend on each other, `make` or `just`
is the better tool, and ez is happy to sit next to them. It's macOS-only,
because secrets live in the Keychain. And as with a Makefile, running aliases
from a repository you cloned runs whatever its authors wrote — read
`.ez_cli.json` (or `ez list`) first.

## Try it

```sh
brew tap urtti/ez && brew install ez
cd your-project
ez add hi 'echo hello from {1}'
ez hi ez
```

MIT-licensed, on GitHub: https://github.com/urtti/ez. Issues and ideas very
welcome — especially what would stop you from committing an `.ez_cli.json` to
a shared repo.

*— Tommi Urtti*
