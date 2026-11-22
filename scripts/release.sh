#!/usr/bin/env bash
# Cuts a release: universal build, Developer ID signing, notarization, stapling, zip, and a
# draft GitHub Release. See RELEASING.md for the one-time setup.
#
#   scripts/release.sh <version> [--dry-run]
#
# --dry-run signs with the local dev certificate, skips notarization and the GitHub Release,
# and leaves the zip in build/.
#
# Environment (not needed for --dry-run):
#   DEVELOPER_ID    signing identity, e.g. "Developer ID Application: Josh Sherman (TEAMID)"
#   NOTARY_PROFILE  notarytool keychain profile name (default: hautekey)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version> [--dry-run]}"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 1; }
TAG="v$VERSION"
ZIP="build/HauteKey-$VERSION.zip"
APP="build/Haute Key.app"

if ! $DRY_RUN; then
    [[ -z "$(git status --porcelain)" ]] || { echo "commit or stash your changes first" >&2; exit 1; }
    [[ "$(git branch --show-current)" == "main" ]] || { echo "release from main" >&2; exit 1; }
    ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "$TAG already exists" >&2; exit 1; }
    : "${DEVELOPER_ID:?set DEVELOPER_ID to your Developer ID Application identity}"
    command -v gh >/dev/null || { echo "needs the GitHub CLI (brew install gh)" >&2; exit 1; }
fi

if $DRY_RUN; then
    scripts/package.sh "Haute Key Dev" --version "$VERSION" --universal
else
    scripts/package.sh "$DEVELOPER_ID" --version "$VERSION" --universal --timestamp
fi

echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/HauteKey")"

rm -f "$ZIP"
if $DRY_RUN; then
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Dry run: skipped notarization and GitHub Release."
else
    # Notarize a zip of the signed app, then staple the ticket to the app and zip it again.
    ditto -c -k --keepParent "$APP" "build/notarize.zip"
    xcrun notarytool submit "build/notarize.zip" --keychain-profile "${NOTARY_PROFILE:-hautekey}" --wait
    xcrun stapler staple "$APP"
    rm -f "build/notarize.zip"
    spctl --assess --type execute --verbose "$APP"
    ditto -c -k --keepParent "$APP" "$ZIP"
fi

SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
echo "Built $ZIP"
echo "sha256 $SHA"

if ! $DRY_RUN; then
    git tag -a "$TAG" -m "Haute Key $VERSION"
    git push origin "$TAG"
    gh release create "$TAG" "$ZIP" --draft --title "Haute Key $VERSION" --generate-notes
    echo "Draft release $TAG created. Review and publish it on GitHub, then update the cask:"
    echo "  version \"$VERSION\""
    echo "  sha256 \"$SHA\""
fi
