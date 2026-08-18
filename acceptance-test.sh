#!/bin/bash
set -e

# Automated acceptance tests for ez CLI
# Run from the project root directory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)
PASS=0
FAIL=0

# Keep run history out of the real ~/.ez
export EZCLI_HOME="$TEST_DIR/ez_home"

cleanup() {
    rm -rf "$TEST_DIR"
    # The keychain is not isolated by EZCLI_HOME, so the canary item is always cleaned up
    security delete-generic-password -s com.urtti.ez -a EZ_ACCEPTANCE_TEST_CANARY > /dev/null 2>&1 || true
}
trap cleanup EXIT

ez() {
    "$EZ_BIN" "$@" 2>&1
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    if echo "$output" | grep -q "$expected"; then
        echo "✓ $test_name"
        ((++PASS))
    else
        echo "✗ $test_name"
        echo "  Expected to contain: $expected"
        echo "  Got: $output"
        ((++FAIL))
    fi
}

assert_equals() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    if [ "$output" = "$expected" ]; then
        echo "✓ $test_name"
        ((++PASS))
    else
        echo "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Got: $output"
        ((++FAIL))
    fi
}

assert_exit_code() {
    local test_name="$1"
    local expected_code="$2"
    shift 2

    set +e
    "$@" > /dev/null 2>&1
    local actual_code=$?
    set -e

    if [ "$actual_code" -eq "$expected_code" ]; then
        echo "✓ $test_name"
        ((++PASS))
    else
        echo "✗ $test_name"
        echo "  Expected exit code: $expected_code"
        echo "  Got: $actual_code"
        ((++FAIL))
    fi
}

echo "Building ez..."
swift build --package-path "$SCRIPT_DIR" -q

# Use the built binary directly (faster, no build noise)
EZ_BIN="$SCRIPT_DIR/.build/debug/ez"

if [ ! -f "$EZ_BIN" ]; then
    echo "Error: Binary not found at $EZ_BIN"
    exit 1
fi

echo ""
echo "Running acceptance tests in $TEST_DIR"
echo "======================================="
cd "$TEST_DIR"

# --version
echo ""
echo "## Version and Help"
output=$(ez --version)
# Prefix-agnostic: release.sh writes whatever it is given into VERSION, with or without a leading v
assert_contains "$output" "[0-9]\+\.[0-9]\+\.[0-9]\+" "--version outputs version"

output=$(ez --help)
assert_contains "$output" "Streamlines CLI command execution" "--help shows abstract"
assert_contains "$output" "add" "--help shows add command"
assert_contains "$output" "remove" "--help shows remove command"
assert_contains "$output" "list" "--help shows list command"

# Empty list
echo ""
echo "## Empty State"
output=$(ez list)
assert_contains "$output" "No aliases defined" "list shows no aliases initially"

# Add alias
echo ""
echo "## Add Command"
output=$(ez add hello "echo hello world")
output=$(ez list)
assert_contains "$output" "hello" "list shows added alias"

# Execute alias
echo ""
echo "## Execute Alias"
output=$(ez hello)
assert_contains "$output" "hello world" "alias outputs expected text"
assert_contains "$output" "Executing" "shows executing message"

# Add with description
output=$(ez add greet -d "A greeting command" "echo hi there")
output=$(ez list -v)
assert_contains "$output" "greet" "list shows second alias"
assert_contains "$output" "A greeting command" "verbose list shows description"

# Remove alias
echo ""
echo "## Remove Command"
ez remove hello
output=$(ez list)
if echo "$output" | grep -q "ez hello"; then
    echo "✗ remove deletes alias"
    ((++FAIL))
else
    echo "✓ remove deletes alias"
    ((++PASS))
fi

# Protected keywords
echo ""
echo "## Error Cases"
output=$(ez add list "echo x" 2>&1 || true)
assert_contains "$output" "protected keyword" "cannot add alias named 'list'"

output=$(ez add add "echo x" 2>&1 || true)
assert_contains "$output" "protected keyword" "cannot add alias named 'add'"

output=$(ez nonexistent 2>&1 || true)
assert_contains "$output" "Unknown alias" "unknown alias shows error"

# Parallel execution
echo ""
echo "## Parallel Execution"
ez add parallel -p "echo one" "echo two"
output=$(ez parallel)
assert_contains "$output" "one" "parallel outputs first command"
assert_contains "$output" "two" "parallel outputs second command"
assert_contains "$output" "Running in parallel" "shows parallel message"

# Command with arguments
echo ""
echo "## Commands with Arguments"
ez add math "echo \$((2 + 2))"
output=$(ez math)
assert_contains "$output" "4" "command with shell expansion works"

# Multiple sequential commands
ez add multi "echo first && echo second"
output=$(ez multi)
assert_contains "$output" "first" "sequential commands - first"
assert_contains "$output" "second" "sequential commands - second"

# Parameter substitution
echo ""
echo "## Parameter Substitution"
ez add pgreet 'echo hello {1}'
output=$(ez pgreet world)
assert_contains "$output" "hello world" "single placeholder substitution"

ez add phi 'echo {1} and {2}'
output=$(ez phi foo bar)
assert_contains "$output" "foo and bar" "multiple placeholder substitution"

ez add special 'echo {1} {2}'
output=$(ez special "(25,9)" .)
assert_contains "$output" "(25,9) ." "placeholder substitution shell-escapes special characters"

ez add spaced 'echo {1}::{2}'
output=$(ez spaced "hello world" "two words")
assert_contains "$output" "hello world::two words" "multiple placeholders preserve spaced arguments"

ez add prep 'echo {1} {1} {1}'
output=$(ez prep yo)
assert_contains "$output" "yo yo yo" "repeated placeholder substitution"

output=$(ez pgreet 2>&1 || true)
assert_contains "$output" "Expected 1 argument(s)" "missing args shows error"

output=$(ez list)
assert_contains "$output" "{1}" "list shows placeholder templates"

## Extra Arguments Appended
ez add noparams "echo static"
output=$(ez noparams extraarg)
assert_contains "$output" "static extraarg" "extra args appended to non-parameterized alias"

output=$(ez noparams)
assert_contains "$output" "static" "no extra args still works"

ez add pappend "echo hello {1}"
output=$(ez pappend world extra1 extra2)
assert_contains "$output" "hello world extra1 extra2" "extra args appended after placeholder substitution"

ez add spacey "echo test"
output=$(ez spacey "hello world")
assert_contains "$output" "hello world" "extra arg with spaces is preserved"

# Secrets placeholder in aliases
echo ""
echo "## Secret Placeholders"
ez add secretcmd 'echo token={EZ_API_KEY} and extra={EZ_OTHER}'
output=$(ez list)
assert_contains "$output" "secretcmd" "alias with secret placeholders is listed"
output=$(ez list -v)
assert_contains "$output" "{EZ_API_KEY}" "verbose list shows secret placeholder"

# add-secret key validation
echo ""
echo "## Add-Secret Validation"
output=$(ez add-secret --key BADKEY --value test 2>&1 || true)
assert_contains "$output" "Must start with EZ_" "add-secret rejects key without EZ_ prefix"

output=$(ez add-secret --key EZ_lower --value test 2>&1 || true)
assert_contains "$output" "Must start with EZ_" "add-secret rejects lowercase key"

# Protected keywords for secrets
echo ""
echo "## Secret Protected Keywords"
output=$(ez add add-secret "echo x" 2>&1 || true)
assert_contains "$output" "protected keyword" "cannot add alias named 'add-secret'"

output=$(ez add remove-secret "echo x" 2>&1 || true)
assert_contains "$output" "protected keyword" "cannot add alias named 'remove-secret'"

# Help shows new commands
output=$(ez --help)
assert_contains "$output" "add-secret" "--help shows add-secret command"
assert_contains "$output" "remove-secret" "--help shows remove-secret command"

# Run history
echo ""
echo "## Run History"
output=$(ez add stats "echo x" 2>&1 || true)
assert_contains "$output" "protected keyword" "cannot add alias named 'stats'"

output=$(ez --help)
assert_contains "$output" "stats" "--help shows stats command"

output=$(ez stats nohistory)
assert_contains "$output" "No run history" "stats shows friendly empty state"

ez add statsrun "echo counted" > /dev/null
ez statsrun > /dev/null
ez statsrun > /dev/null
output=$(ez stats statsrun)
assert_contains "$output" "Recent runs" "stats shows recent runs header"
assert_equals "$(echo "$output" | grep -c "ok")" "2" "stats lists both runs"

ez add statsfail "exit 3" > /dev/null
ez statsfail > /dev/null 2>&1 || true
output=$(ez stats statsfail)
assert_contains "$output" "exit 3" "stats records non-zero exit code"

ez add statspar -p "echo a" "echo b" > /dev/null
ez statspar > /dev/null
output=$(ez stats statspar)
assert_equals "$(echo "$output" | grep -c "ok")" "1" "parallel invocation records exactly one run"

template=$(sqlite3 "$EZCLI_HOME/runs.db" "select command_template from runs where alias_name = 'statspar'")
assert_equals "$template" "echo a ;; echo b" "parallel alias records its commands without reading as a pipeline"

# The recorded code is the first failure in command order, not the first job to finish
ez add statsparfail -p "sleep 0.2; exit 3" "exit 4" > /dev/null
ez statsparfail > /dev/null 2>&1 || true
code=$(sqlite3 "$EZCLI_HOME/runs.db" "select exit_code from runs where alias_name = 'statsparfail'")
assert_equals "$code" "3" "parallel exit code is the first failing command, not the first to finish"

if [ -f "$EZCLI_HOME/runs.db" ]; then
    echo "✓ run history database lives under EZCLI_HOME"
    ((++PASS))
else
    echo "✗ run history database lives under EZCLI_HOME"
    ((++FAIL))
fi

templates=$(sqlite3 "$EZCLI_HOME/runs.db" "select command_template from runs where alias_name = 'statsrun'")
assert_equals "$templates" "echo counted
echo counted" "database stores the alias definition per invocation"

cwds=$(sqlite3 "$EZCLI_HOME/runs.db" "select distinct cwd from runs")
assert_equals "$cwds" "$(pwd -P)" "runs are scoped to the directory they ran in"

# Run history never persists resolved values
echo ""
echo "## Run History Secret Safety"
# A key that no real keychain holds, so this never reads the developer's own secrets
ez add statssecret 'echo token={EZ_ACCEPTANCE_TEST_ABSENT_KEY}' > /dev/null
output=$(ez statssecret 2>&1 || true)
assert_contains "$output" "Failed to read secret" "alias with unavailable secret aborts"
output=$(ez stats statssecret)
assert_contains "$output" "No run history" "aborted secret alias records no run"

# Positive check: a secret alias that actually runs must record the placeholder, not the value.
# Needs a real keychain item, so it is skipped when the keychain is unavailable.
CANARY_VALUE="leakcanary987"
if ez add-secret --key EZ_ACCEPTANCE_TEST_CANARY --value "$CANARY_VALUE" --force > /dev/null 2>&1; then
    ez add statscanary 'echo token={EZ_ACCEPTANCE_TEST_CANARY}' > /dev/null
    ez statscanary > /dev/null 2>&1
    template=$(sqlite3 "$EZCLI_HOME/runs.db" "select command_template from runs where alias_name = 'statscanary'")
    assert_equals "$template" "echo token={EZ_ACCEPTANCE_TEST_CANARY}" "executed secret alias records the placeholder form"
    if grep -q "$CANARY_VALUE" "$EZCLI_HOME"/runs.db* 2>/dev/null; then
        echo "✗ database bytes never hold a resolved secret"
        ((++FAIL))
    else
        echo "✓ database bytes never hold a resolved secret"
        ((++PASS))
    fi

    # Parallel mode prints the pre-substitution text, so secrets stay out of the terminal
    ez add statscanarypar -p 'echo token={EZ_ACCEPTANCE_TEST_CANARY} > /dev/null' "echo b > /dev/null" > /dev/null
    canary_output=$(ez statscanarypar 2>&1 || true)
    if echo "$canary_output" | grep -q "$CANARY_VALUE"; then
        echo "✗ parallel output never prints a resolved secret"
        ((++FAIL))
    else
        echo "✓ parallel output never prints a resolved secret"
        ((++PASS))
    fi
    ez remove-secret EZ_ACCEPTANCE_TEST_CANARY > /dev/null 2>&1 || true
else
    echo "⚠ skipped keychain canary tests (keychain unavailable)"
fi

ez add statsparam 'echo value={1}' > /dev/null
ez statsparam supersecretvalue123 > /dev/null
dump=$(sqlite3 "$EZCLI_HOME/runs.db" "select command_template from runs")
assert_contains "$dump" "{1}" "database stores the literal {1} placeholder"
if echo "$dump" | grep -q "supersecretvalue123"; then
    echo "✗ database does not store substituted values"
    ((++FAIL))
else
    echo "✓ database does not store substituted values"
    ((++PASS))
fi

# Summary and trend
echo ""
echo "## Run Summary and Trend"

seed_run() {
    # alias, duration_ms, started_at, exit_code (default 0)
    sqlite3 "$EZCLI_HOME/runs.db" "insert into runs (cwd, alias_name, command_template, execution_type, exit_code, duration_ms, started_at) values ('$(pwd -P)', '$1', 'seeded', 'sequential', ${4:-0}, $2, $3)"
}

# Even sample count: median is the mean of the two middle values
for pair in "100 2000" "200 2001" "300 2002" "400 2003"; do
    seed_run seededeven ${pair% *} ${pair#* }
done
output=$(ez stats seededeven)
assert_contains "$output" "min 100 ms" "summary reports min"
assert_contains "$output" "median 250 ms" "median of an even sample count averages the middle two"
assert_contains "$output" "p90 400 ms" "summary reports p90"
assert_contains "$output" "max 400 ms" "summary reports max"
assert_contains "$output" "4 successful run(s)" "summary counts successful runs"

# Failed runs are excluded from the statistics
seed_run seededfail 100 2000
seed_run seededfail 100 2001
seed_run seededfail 100 2002
seed_run seededfail 1 2003 3
output=$(ez stats seededfail)
assert_contains "$output" "median 100 ms" "failed run does not drag the median"
assert_contains "$output" "3 successful run(s)" "failed run is not counted in the summary"

# Trend: most recent 5 vs the previous 5, with an older row that must fall outside both windows
seed_run seededtrend 5000 1999
for at in 2000 2001 2002 2003 2004; do
    seed_run seededtrend 100 $at
done
for at in 2005 2006 2007 2008 2009; do
    seed_run seededtrend 200 $at
done
output=$(ez stats seededtrend)
assert_contains "$output" "100% slower" "trend compares the recent window against the previous one"
assert_contains "$output" "last 5 median 200 ms vs 100 ms before" "trend windows slice exactly 5 runs each"

# Below the 15% threshold nothing is reported as a change
for at in 2000 2001 2002 2003 2004; do
    seed_run seededsteady 100 $at
done
for at in 2005 2006 2007 2008 2009; do
    seed_run seededsteady 110 $at
done
output=$(ez stats seededsteady)
assert_contains "$output" "steady" "a change under the threshold reports steady"

# Fewer than 2N successful runs has no trend
for at in 2000 2001 2002; do
    seed_run seededshort 100 $at
done
output=$(ez stats seededshort)
assert_contains "$output" "not enough data" "insufficient history prints the not-enough-data message"
assert_contains "$output" "10 successful runs needed" "not-enough-data message states the requirement"

# A zero-duration previous window is no baseline to compare against, not steadiness
for at in 2000 2001 2002 2003 2004; do
    seed_run seededzero 0 $at
done
for at in 2005 2006 2007 2008 2009; do
    seed_run seededzero 800 $at
done
output=$(ez stats seededzero)
assert_contains "$output" "no baseline" "a zero previous median declines to judge instead of reporting steady"

# Real runs: a slow window after a fast one reads as slower
ez add trendy "sleep 0.02" > /dev/null
for i in 1 2 3 4 5; do ez trendy > /dev/null; done
output=$(ez stats trendy)
assert_contains "$output" "not enough data" "five real runs are not enough for a trend"
ez add trendy "sleep 0.3" > /dev/null
for i in 1 2 3 4 5; do ez trendy > /dev/null; done
output=$(ez stats trendy)
assert_equals "$(sqlite3 "$EZCLI_HOME/runs.db" "select count(*) from runs where alias_name = 'trendy' and duration_ms > 0")" "10" "real runs record a non-zero duration"
assert_contains "$output" "slower" "slower real runs read as slower"

# ...and the reverse
ez add trendyfast "sleep 0.3" > /dev/null
for i in 1 2 3 4 5; do ez trendyfast > /dev/null; done
ez add trendyfast "sleep 0.02" > /dev/null
for i in 1 2 3 4 5; do ez trendyfast > /dev/null; done
output=$(ez stats trendyfast)
assert_contains "$output" "faster" "faster real runs read as faster"

# Bare 'ez stats' overview
output=$(ez stats)
assert_contains "$output" "Run history" "bare stats shows the overview header"
assert_contains "$output" "ez seededtrend" "bare stats lists aliases with history"
assert_contains "$output" "median 250 ms" "bare stats shows a median per alias"
assert_contains "$output" "10 of 10 run(s) ok" "bare stats counts successful runs against every run"
assert_contains "$output" "3 of 4 run(s) ok" "bare stats shows failed runs in the same denominator"
assert_contains "$output" "↑" "bare stats shows a trend arrow"
assert_contains "$output" "none successful" "bare stats flags aliases without successful runs"

mkdir -p "$TEST_DIR/other"
output=$(cd "$TEST_DIR/other" && "$EZ_BIN" stats 2>&1)
assert_contains "$output" "No run history in this directory" "overview is scoped to the current directory"

# A run says something about itself only when it is worth saying
echo ""
echo "## Per-run Outlier Notes"

# Baseline seeded at 600 ms so the real runs below only have to differ, not repeat
seed_baseline() {
    # alias, duration_ms
    for i in 1 2 3 4 5 6; do
        seed_run "$1" "$2" $((3000 + i))
    done
}

seed_baseline noteslow 600
ez add noteslow 'sleep 1.1' > /dev/null
output=$(ez noteslow)
assert_contains "$output" "slower than median 600 ms" "a slow run is called out against its baseline"

seed_baseline notefast 6000
ez add notefast 'sleep 0.6' > /dev/null
output=$(ez notefast)
assert_contains "$output" "faster than median 6.000 s" "a run that got much faster is called out too"

seed_baseline notesteady 600
ez add notesteady 'sleep 0.62' > /dev/null
output=$(ez notesteady)
if echo "$output" | grep -q "than median"; then
    echo "✗ a run within the threshold stays quiet"
    ((++FAIL))
else
    echo "✓ a run within the threshold stays quiet"
    ((++PASS))
fi

# A trivially fast alias is never annotated, however far off its baseline it lands
seed_baseline notetrivial 2
ez add notetrivial 'echo x' > /dev/null
output=$(ez notetrivial)
if echo "$output" | grep -q "than median"; then
    echo "✗ a trivially fast alias is never annotated"
    ((++FAIL))
else
    echo "✓ a trivially fast alias is never annotated"
    ((++PASS))
fi

# A failed run is not compared against a successful-run baseline
seed_baseline notefail 600
ez add notefail 'sleep 1.1; exit 1' > /dev/null
output=$(ez notefail 2>&1 || true)
if echo "$output" | grep -q "than median"; then
    echo "✗ a failed run is never compared against the baseline"
    ((++FAIL))
else
    echo "✓ a failed run is never compared against the baseline"
    ((++PASS))
fi

# Too few prior runs means no trustworthy baseline
seed_run notethin 600 3001
seed_run notethin 600 3002
ez add notethin 'sleep 1.1' > /dev/null
output=$(ez notethin)
if echo "$output" | grep -q "than median"; then
    echo "✗ too few prior runs produces no note"
    ((++FAIL))
else
    echo "✓ too few prior runs produces no note"
    ((++PASS))
fi

# ez exits with the code of the work it drove, so `ez test && deploy` behaves
echo ""
echo "## Exit Codes"
ez add exitok 'exit 0' > /dev/null
assert_exit_code "successful alias exits 0" 0 ez exitok

ez add exitboom 'exit 3' > /dev/null
assert_exit_code "failing alias propagates its exit code" 3 ez exitboom

ez add exitsig 'kill -TERM $$' > /dev/null
assert_exit_code "signal-killed alias exits 128 + signal" 143 ez exitsig

ez add exitpar -p 'exit 0' 'exit 7' > /dev/null
assert_exit_code "parallel alias reports the first non-zero code" 7 ez exitpar

ez add exitparok -p 'exit 0' 'exit 0' > /dev/null
assert_exit_code "all-successful parallel alias exits 0" 0 ez exitparok

# The recorded exit code and the process exit code must agree
ez exitboom > /dev/null 2>&1 || true
recorded=$(sqlite3 "$EZCLI_HOME/runs.db" "select exit_code from runs where alias_name = 'exitboom' limit 1")
assert_equals "$recorded" "3" "recorded exit code matches the process exit code"

assert_exit_code "unknown alias exits 1" 1 ez no-such-alias-exists

ez add exitargs 'echo hello {1}' > /dev/null
assert_exit_code "missing arguments exits 1" 1 ez exitargs

ez add exitsecret 'echo {EZ_ACCEPTANCE_TEST_MISSING_CANARY}' > /dev/null
assert_exit_code "unreadable secret exits 1" 1 ez exitsecret

# Summary
echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
