#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_NAME="InputLock"
BUILD_DIR=".build-debug"
APP_DIR="$BUILD_DIR/$PROJECT_NAME.app"
LOG_DIR="$BUILD_DIR/logs"
LLDB_LOG="$LOG_DIR/lldb.log"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$LOG_DIR"

xcrun swiftc \
  -g \
  -Onone \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/$PROJECT_NAME"

cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null

killall "$PROJECT_NAME" 2>/dev/null || true

cat > "$BUILD_DIR/lldb.commands" <<EOF
settings set target.process.stop-on-sharedlibrary-events false
settings set target.process.thread.step-avoid-regexp ^(AppKit|Foundation|Carbon|CoreFoundation|libsystem).*
settings set auto-confirm true
target create "$APP_DIR/Contents/MacOS/$PROJECT_NAME"
settings set target.env-vars NSUnbufferedIO=YES
process launch --stdout "$LOG_DIR/stdout.log" --stderr "$LOG_DIR/stderr.log"
EOF

echo "Debug app: $(pwd)/$APP_DIR"
echo "LLDB log: $(pwd)/$LLDB_LOG"
echo "Waiting for a crash. Reproduce the issue, then leave the process stopped."

xcrun lldb \
  -s "$BUILD_DIR/lldb.commands" \
  >"$LLDB_LOG" 2>&1

echo "LLDB stopped. Crash output saved to: $(pwd)/$LLDB_LOG"
