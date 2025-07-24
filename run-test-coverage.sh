#!/bin/sh
set -e
swift test --enable-code-coverage -Xswiftc -DUNIT_TEST "$@"
COV_PATH=".build/arm64-apple-macosx/debug/codecov/default.profdata"
BINARY_PATH=".build/debug/ezcliPackageTests.xctest/Contents/MacOS/ezcliPackageTests"
xcrun llvm-cov report "$BINARY_PATH" -instr-profile "$COV_PATH" 