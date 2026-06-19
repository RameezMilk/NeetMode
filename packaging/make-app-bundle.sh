#!/usr/bin/env bash
#
# Build NeetMode in release mode and assemble it into a proper .app bundle.
# A bundle (with Info.plist) is what makes LSUIElement + the Apple Events
# usage-description prompt work correctly.
#
# Usage:   ./packaging/make-app-bundle.sh
# Output:  ./build/NeetMode.app
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/NeetMode.app"
BIN_NAME="NeetMode"

echo "==> Building release binary…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "!! Could not find built binary at $BIN_PATH" >&2
  exit 1
fi

echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
cp packaging/Info.plist "$APP/Contents/Info.plist"
cp web/index.html "$APP/Contents/Resources/index.html"   # reference copy

# Ad-hoc code signature. macOS ties the Automation (Apple Events) permission to
# the app's signing identity; ad-hoc signing keeps that grant stable across runs.
echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP"

echo ""
echo "Done: $ROOT/$APP"
echo "Drag it to /Applications, then launch it once and grant the Automation prompt."
