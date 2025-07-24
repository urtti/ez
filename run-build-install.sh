#!/bin/bash
set -e

# Fetch dependencies
swift package resolve

# Build the CLI
swift build -c release

# Find the built executable
EXECUTABLE=".build/arm64-apple-macosx/release/ez"

if [ ! -f "$EXECUTABLE" ]; then
  echo "❌ Build failed or executable not found at $EXECUTABLE"
  exit 1
fi

# Copy to /usr/local/bin (may require sudo)
echo "Copying $EXECUTABLE to /usr/local/bin/ez..."
sudo cp "$EXECUTABLE" /usr/local/bin/ez
chmod +x /usr/local/bin/ez
echo "✅ - 🐘 ez installed to /usr/local/bin/ez" 