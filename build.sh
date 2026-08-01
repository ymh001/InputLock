#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_NAME="InputLock"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$PROJECT_NAME.app"
SWIFT_SOURCES="Sources"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

xcrun swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -framework AppKit \
  -framework Carbon \
  "$SWIFT_SOURCES"/*.swift \
  -o "$APP_DIR/Contents/MacOS/$PROJECT_NAME"

cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR" 2>/dev/null

echo "Built: $(pwd)/$APP_DIR"
