#!/usr/bin/env bash
# Builds, signs with the local dev certificate, and installs "Haute Key.app" to ~/Applications.
# Pass --open to launch it.
set -euo pipefail

cd "$(dirname "$0")/.."

DEST="$HOME/Applications/Haute Key.app"

scripts/package.sh "Haute Key Dev"

# Quit gracefully so the app clears its key mapping; pkill is the fallback.
osascript -e 'quit app id "com.joshtronic.hautekey"' 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x HauteKey >/dev/null || break; sleep 0.3; done
pkill -x HauteKey || true

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "build/Haute Key.app" "$DEST"
touch "$DEST"  # nudges Finder to pick up icon changes
echo "Installed $DEST"

if [[ "${1:-}" == "--open" ]]; then
    # LaunchServices can lag behind a fresh install (error -600); retry briefly.
    for _ in 1 2 3; do open "$DEST" 2>/dev/null && break; sleep 1; done
fi
