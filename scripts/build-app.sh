#!/usr/bin/env bash
# Builds, signs, and installs "Haute Key.app" to ~/Applications. Pass --open to launch it.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Haute Key.app"
DEST="$HOME/Applications/Haute Key.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/HauteKey" "$APP/Contents/MacOS/HauteKey"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --sign "Haute Key Dev" --identifier dev.hautekey.app "$APP"

pkill -x HauteKey || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
touch "$DEST"  # nudges Finder to pick up icon changes
echo "Installed $DEST"

if [[ "${1:-}" == "--open" ]]; then
    open "$DEST"
fi
