#!/usr/bin/env bash
# Builds and signs build/Haute Key.app. Used by build-app.sh (dev) and release.sh (Developer ID).
#
#   scripts/package.sh <signing identity> [--version X.Y.Z] [--universal] [--timestamp]
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${1:?usage: package.sh <signing identity> [--version X.Y.Z] [--universal] [--timestamp]}"
shift
VERSION=""
ARCHS=()
TIMESTAMP=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --universal) ARCHS=(--arch arm64 --arch x86_64); shift ;;
        --timestamp) TIMESTAMP=(--timestamp); shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

APP="build/Haute Key.app"

swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/HauteKey"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HauteKey"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "$VERSION" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    # Build number: the commit count, so every release sorts after the last.
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" "$APP/Contents/Info.plist"
fi

codesign --force --options runtime ${TIMESTAMP[@]+"${TIMESTAMP[@]}"} \
    --sign "$IDENTITY" --identifier com.joshtronic.hautekey "$APP"
codesign --verify --deep --strict "$APP"
echo "Packaged $APP"
