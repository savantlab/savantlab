#!/usr/bin/env bash
set -euo pipefail

# Build and run the macOS trackpad logging app.
# Requirements:
#   - Xcode installed (not just Command Line Tools)
#   - xcodebuild available and pointing at the Xcode app (xcode-select -s /Applications/Xcode.app/Contents/Developer)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR%/scripts}"
APP_PROJECT_DIR="$PROJECT_ROOT/savantlab-trackpad-macOS"
DERIVED_DATA_DIR="$PROJECT_ROOT/build"

cd "$APP_PROJECT_DIR"

# Build the macOS app into a local DerivedData directory under the project root.
xcodebuild \
  -project savantlab-trackpad-macOS.xcodeproj \
  -scheme savantlab \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/savantlab.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app not found at: $APP_PATH" >&2
  exit 1
fi

open "$APP_PATH"
