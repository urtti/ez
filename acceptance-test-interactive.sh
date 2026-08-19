#!/bin/bash

# Interactive acceptance tests for ez CLI
# These tests require a human to verify TTY behavior

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEST_DIR"
    # The keychain is not isolated by EZCLI_HOME, and this script invites Ctrl+C,
    # so the canary item is always cleaned up rather than only in the last test
    security delete-generic-password -s com.urtti.ez -a EZ_INTERACTIVE_TEST_CANARY > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Keep run history out of the real ~/.ez
export EZCLI_HOME="$TEST_DIR/ez_home"

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
echo "## Test 7: Add secret to keychain (deprecated --value)"
echo "Expected: --value deprecation warning, Touch ID / password prompt, then confirmation"
echo "Running: ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value hello_secret"
prompt
ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value hello_secret

echo ""
echo "## Test 8: Add duplicate secret (should fail)"
echo "Expected: --value deprecation warning, then error about existing key"
echo "Running: ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value other"
prompt
ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value other || true

echo ""
echo "## Test 9: Force overwrite secret"
echo "Expected: --value deprecation warning, Touch ID / password prompt, then confirmation"
echo "Running: ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value updated_secret --force"
prompt
ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --value updated_secret --force

echo ""
echo "## Test 10: Hidden prompt (no --value)"
echo "Expected: 'Enter value for EZ_INTERACTIVE_TEST_CANARY:' prompt; typed input stays invisible (like sudo)"
echo "Type: prompted_secret and press Enter"
echo "Running: ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --force"
prompt
ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --force

echo ""
echo "## Test 11: Cancel hidden prompt (Ctrl+C)"
echo "Expected: type a few characters (invisible), then press Ctrl+C. ez exits without"
echo "storing anything, and the terminal still echoes typed input afterwards — verify by"
echo "typing at the next 'Press Enter' prompt. Test 12 confirms the secret is unchanged."
echo "Running: ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --force"
prompt
# The script must survive the child dying of SIGINT, so catch INT around this one call
trap ':' INT
ez add-secret --key EZ_INTERACTIVE_TEST_CANARY --force || true
trap - INT

echo ""
echo "## Test 12: Execute alias with secret placeholder"
ez add secrettest 'echo The secret is {EZ_INTERACTIVE_TEST_CANARY}'
echo "Expected: 'Executing: echo The secret is {EZ_INTERACTIVE_TEST_CANARY}' then outputs 'The secret is prompted_secret'"
echo "Running: ez secrettest"
prompt
ez secrettest

echo ""
echo "## Test 13: Run history never stores resolved secrets"
dump=$(sqlite3 "$EZCLI_HOME/runs.db" "select command_template from runs where alias_name = 'secrettest'")
echo "Recorded template: $dump"
if echo "$dump" | grep -q '{EZ_INTERACTIVE_TEST_CANARY}' && ! echo "$dump" | grep -q 'prompted_secret'; then
    echo "✓ database holds {EZ_INTERACTIVE_TEST_CANARY} and not the secret value"
else
    echo "✗ database does not hold the placeholder form"
fi
prompt

echo ""
echo "## Test 14: Remove secret from keychain"
echo "Expected: Confirmation that secret was removed"
echo "Running: ez remove-secret EZ_INTERACTIVE_TEST_CANARY"
prompt
ez remove-secret EZ_INTERACTIVE_TEST_CANARY

echo ""
echo "============================="
echo "Interactive tests complete!"
echo "Clean up: removing $TEST_DIR"
