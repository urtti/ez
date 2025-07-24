#!/bin/bash
set -euo pipefail

# Check for required software
deps=(gh git swift tar shasum)
for dep in "${deps[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: Required dependency '$dep' is not installed or not in PATH. Please install it before running this script."
    exit 1
  fi
done

# Check for Homebrew tap repo in ../homebrew-ez
TAP_DIR="../homebrew-ez"
if [ ! -d "$TAP_DIR" ] || [ ! -d "$TAP_DIR/.git" ]; then
  echo "ERROR: Homebrew tap repo not found at $TAP_DIR or it is not a git repository."
  echo "Please ensure your tap repo exists at $TAP_DIR and is a git repo."
  exit 1
fi

FORMULA_FILE="Formula/ez.rb"
FORMULA_PATH="$TAP_DIR/$FORMULA_FILE"
# Check if formula exists
if [ ! -f "$FORMULA_PATH" ]; then
  echo "ERROR: Formula file not found at $FORMULA_PATH."
  echo "Please ensure your tap repo exists at $TAP_DIR and is a git repo."
  exit 1
fi

# Safety check: ensure no files are staged
if [[ -n $(git diff --cached --name-only) ]]; then
  echo "\nERROR: You have staged files in git. Please commit or unstage them before running this script to avoid including unintended changes in the release."
  git diff --cached --name-only
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 <semantic-version> (e.g., 0.7.1)"
  exit 1
fi

VERSION="$1"
TAG="$VERSION"

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
RELEASES_DIR="releases/download"
NEW_RELEASE_DIR="$RELEASES_DIR/$TAG"
NEW_RELEASE_TARBALL="$NEW_RELEASE_DIR/$TARBALL"

# 1. Update version in ez.swift
echo "Updating version in $SWIFT_FILE to $TAG..."
sed -i '' "s/private let VERSION = \".*\"/private let VERSION = \"$TAG\"/" "$SWIFT_FILE"

# 2. Build release binary
echo "Building release binary..."
swift build -c release

# 3. Package the binary
echo "Packaging binary into $TARBALL..."
tar -czf "$TARBALL" -C "$BUILD_DIR" "$BINARY_NAME"

# 4. Calculate SHA256
SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
echo "SHA256: $SHA256"

# 5. Update Homebrew formula
echo "Updating $FORMULA_PATH..."
sed -i '' "s|url \".*\"|url \"https://github.com/urtti/homebrew-ez/releases/download/$TAG/$TARBALL\"|" "$FORMULA_PATH"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA_PATH"
sed -i '' "s|version \".*\"|version \"$TAG\"|" "$FORMULA_PATH"

# 6. Commit and tag (optional, comment out if you want to do this manually)
echo "Committing and tagging release..."
git add "$SWIFT_FILE"
git commit -m "Release $TAG"
git tag "$TAG"

# 7. Push changes and tag
echo "Pushing changes and tag to origin..."
git push
git push origin "$TAG"

# 8. Automate updating Homebrew tap repo
echo "Creating new release directory $TAP_DIR/$NEW_RELEASE_DIR..."
mkdir -p "$TAP_DIR/$NEW_RELEASE_DIR"

echo "Copying $TARBALL to $TAP_DIR/$NEW_RELEASE_TARBALL..."
mv "$TARBALL" "$TAP_DIR/$NEW_RELEASE_TARBALL"

echo "Copying updated formula to tap repo and pushing..."
# cp "$FORMULA_PATH" "$TAP_DIR/Formula/ez.rb"
cd "$TAP_DIR"

# Push tag also to brew repo
echo "Pushing changes and tag to brew repo..."
git tag "$TAG"
git push
git push origin "$TAG"

echo "Creating GitHub release and uploading asset..."
if gh release view "$TAG" &>/dev/null; then
  echo "Release $TAG already exists, uploading asset..."
  gh release upload "$TAG" "$NEW_RELEASE_TARBALL" --clobber
else
  gh release create "$TAG" "$NEW_RELEASE_TARBALL" --title "$TAG" --notes "Release $TAG"
fi

echo "Release $TAG published and asset uploaded!"

git add "$FORMULA_FILE" "$NEW_RELEASE_TARBALL"
git commit -m "Update ez formula to $TAG, add release tarball"
git push
cd -

# 10. Print instructions for testing
cat <<EOF

Next steps:
1. Test the new formula locally:
   brew uninstall ez || true
   brew install --build-from-source $FORMULA_PATH

   # or, if using a tap:
   brew tap urtti/ez
   brew install ez

EOF 