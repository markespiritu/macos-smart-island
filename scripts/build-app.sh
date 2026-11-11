#!/usr/bin/env bash
# Builds Smart Island.app into ./build. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Smart Island.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SmartIsland" "$APP/Contents/MacOS/SmartIsland"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature: enough to run on your own Mac.
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x SmartIsland 2>/dev/null || true
    rm -rf "/Applications/Smart Island.app"
    cp -R "$APP" /Applications/
    open "/Applications/Smart Island.app"
    echo "Installed and launched /Applications/Smart Island.app"
fi
