#!/bin/bash
set -e

# Automated acceptance tests for ez CLI
# Run from the project root directory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TEST_DIR"
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
assert_contains "$output" "v[0-9]\+\.[0-9]\+\.[0-9]\+" "--version outputs version"

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

ez add prep 'echo {1} {1} {1}'
output=$(ez prep yo)
assert_contains "$output" "yo yo yo" "repeated placeholder substitution"

output=$(ez pgreet 2>&1 || true)
assert_contains "$output" "Expected 1 argument(s)" "missing args shows error"

output=$(ez list)
assert_contains "$output" "{1}" "list shows placeholder templates"

# Non-parameterized aliases still work with extra args (ignored)
ez add noparams "echo static"
output=$(ez noparams extraarg)
assert_contains "$output" "static" "non-parameterized alias ignores extra args"

# Summary
echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
