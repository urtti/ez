#!/bin/bash
set -euo pipefail

# Builds, signs, packages and publishes a release of ez as a GitHub release
# on urtti/ez. Does NOT touch the Homebrew tap; run promote.sh in the
# homebrew-ez repo to point the formula at a published release.

# Check for required software
deps=(gh git swift tar)
for dep in "${deps[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: Required dependency '$dep' is not installed or not in PATH. Please install it before running this script."
    exit 1
  fi
done

# Safety check: ensure no files are staged
if [[ -n $(git diff --cached --name-only) ]]; then
  echo "\nERROR: You have staged files in git. Please commit or unstage them before running this script to avoid including unintended changes in the release."
  git diff --cached --name-only
  exit 1
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <semantic-version> [release-notes-file] (e.g., 0.7.1 notes.md)"
  exit 1
fi

VERSION="$1"
TAG="$VERSION"
NOTES_FILE="${2:-}"

# Fail early: a missing or empty notes file should not surface after the push.
if [ -n "$NOTES_FILE" ] && [ ! -s "$NOTES_FILE" ]; then
  echo "ERROR: Release notes file '$NOTES_FILE' does not exist or is empty."
  exit 1
fi

# If tag has double v prefix, remove one of them
if [[ "$TAG" == "vv"* ]]; then
  echo "Removing double v prefix from tag..."
  TAG="${TAG:1}"
  echo "New tag: $TAG"
fi

BINARY_NAME="ez"
BUILD_DIR=".build/release"
TARBALL="ez-$TAG-macos.tar.gz"
SWIFT_FILE="ezcli/ez.swift"

# 1. Update version in ez.swift
echo "Updating version in $SWIFT_FILE to $TAG..."
sed -i '' "s/private let VERSION = \".*\"/private let VERSION = \"$TAG\"/" "$SWIFT_FILE"

# 2. Build release binary
echo "Building release binary..."
swift build -c release

# 3. Code-sign binary (required for Keychain access)
# Identity comes from the environment, falling back to the ez Keychain secret
# (ez add-secret --key EZ_CODESIGN_IDENTITY --value "Apple Development: ..."),
# so no personal signing identity lives in this script.
EZ_CODESIGN_IDENTITY="${EZ_CODESIGN_IDENTITY:-$(security find-generic-password -s com.urtti.ez -a EZ_CODESIGN_IDENTITY -w 2>/dev/null || true)}"
if [ -z "$EZ_CODESIGN_IDENTITY" ]; then
  echo "ERROR: No signing identity. Set EZ_CODESIGN_IDENTITY or store it with:"
  echo "  ez add-secret --key EZ_CODESIGN_IDENTITY --value \"Apple Development: Your Name (TEAMID)\""
  exit 1
fi
echo "Code-signing binary..."
codesign --force --sign "$EZ_CODESIGN_IDENTITY" "$BUILD_DIR/$BINARY_NAME"

# 4. Package the binary and completions
echo "Packaging binary and completions into $TARBALL..."
STAGING_DIR=".build/staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/completions"
cp "$BUILD_DIR/$BINARY_NAME" "$STAGING_DIR/"
cp completions/_ez "$STAGING_DIR/completions/"
tar -czf "$TARBALL" -C "$STAGING_DIR" .

# 5. Commit and tag
echo "Committing and tagging release..."
git add "$SWIFT_FILE"
git commit -m "Release $TAG"
git tag "$TAG"

# 6. Push changes and tag
echo "Pushing changes and tag to origin..."
git push
git push origin "$TAG"

# 7. Create GitHub release on urtti/ez and upload the tarball
echo "Creating GitHub release and uploading asset..."
if [ -n "$NOTES_FILE" ]; then
  NOTES_ARGS=(--notes-file "$NOTES_FILE")
else
  NOTES_ARGS=(--notes "Release $TAG")
fi
if gh release view "$TAG" &>/dev/null; then
  echo "Release $TAG already exists, uploading asset..."
  gh release upload "$TAG" "$TARBALL" --clobber
  if [ -n "$NOTES_FILE" ]; then
    echo "Updating release notes from $NOTES_FILE..."
    gh release edit "$TAG" "${NOTES_ARGS[@]}"
  fi
else
  gh release create "$TAG" "$TARBALL" --title "$TAG" "${NOTES_ARGS[@]}"
fi

rm "$TARBALL"

echo "Release $TAG published!"

cat <<EOF

Next steps:
1. Test the release binary:
   gh release download $TAG --pattern "$TARBALL" --dir /tmp
   tar -xzf "/tmp/$TARBALL" -C /tmp && /tmp/ez --version

2. When happy, publish it to Homebrew from the tap repo:
   cd ../homebrew-ez && ./promote.sh $TAG

EOF
