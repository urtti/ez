#!/bin/bash

# Interactive acceptance tests for ez CLI
# These tests require a human to verify TTY behavior

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

prompt() {
    echo ""
    read -p "Press Enter to continue (or Ctrl+C to abort)..."
}

echo "Building ez..."
swift build --package-path "$SCRIPT_DIR" -q

EZ_BIN="$SCRIPT_DIR/.build/debug/ez"

if [ ! -f "$EZ_BIN" ]; then
    echo "Error: Binary not found at $EZ_BIN"
    exit 1
fi

ez() {
    "$EZ_BIN" "$@"
}

echo ""
echo "Interactive Acceptance Tests"
echo "============================="
echo "Test directory: $TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "## Test 1: Colored output"
echo "Adding alias that uses colored ls output..."
ez add colorls "ls -G /tmp"
echo ""
echo "Expected: Directory listing with colors (if terminal supports it)"
echo "Running: ez colorls"
prompt
ez colorls

echo ""
echo "## Test 2: Interactive editor"
echo "Adding alias that opens vim..."
ez add editor "vim $TEST_DIR/testfile.txt"
echo ""
echo "Expected: vim opens, you can type, :wq to save and quit"
echo "Running: ez editor"
prompt
ez editor

if [ -f "$TEST_DIR/testfile.txt" ]; then
    echo "✓ File was created by vim"
else
    echo "Note: No file created (you may have quit without saving)"
fi

echo ""
echo "## Test 3: Interactive pager"
ez add pager "echo -e 'Line 1\nLine 2\nLine 3\nPress q to quit' | less"
echo ""
echo "Expected: less opens with text, press 'q' to quit"
echo "Running: ez pager"
prompt
ez pager

echo ""
echo "## Test 4: Stdin reading"
ez add askname "read 'name?Enter your name: ' && echo Hello, \$name"
echo ""
echo "Expected: Prompt for your name, then greeting"
echo "Running: ez askname"
prompt
ez askname

echo ""
echo "## Test 5: Signal handling (Ctrl+C)"
ez add longsleep "echo 'Sleeping for 30s, press Ctrl+C to interrupt...' && sleep 30 && echo 'Done'"
echo ""
echo "Expected: Press Ctrl+C during sleep, process should terminate cleanly"
echo "Running: ez longsleep"
prompt
ez longsleep

echo ""
echo "## Test 6: Terminal resize (optional)"
ez add toptest "top -l 5"
echo ""
echo "Expected: top runs and shows system stats, exits after 5 iterations"
echo "Running: ez toptest"
prompt
ez toptest

echo ""
echo "============================="
echo "Interactive tests complete!"
echo "Clean up: removing $TEST_DIR"
