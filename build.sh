#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_NAME="InputLock"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$PROJECT_NAME.app"
SWIFT_SOURCES="Sources"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

ICON_TMP_DIR="$BUILD_DIR/InputLock.iconset"
mkdir -p "$ICON_TMP_DIR"
qlmanage -t -s 1024 -o "$BUILD_DIR" Resources/InputLock.svg >/dev/null 2>&1
ICON_PNG="$BUILD_DIR/InputLock.svg.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_PNG" --out "$ICON_TMP_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$ICON_PNG" --out "$ICON_TMP_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_TMP_DIR" -o "$APP_DIR/Contents/Resources/InputLock.icns"

xcrun swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  "$SWIFT_SOURCES"/*.swift \
  -o "$APP_DIR/Contents/MacOS/$PROJECT_NAME"

cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR" 2>/dev/null

echo "Built: $(pwd)/$APP_DIR"
