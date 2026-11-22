# Releasing Haute Key

Releases are universal apps (Apple silicon and Intel), signed with a Developer ID, notarized by
Apple, and published as a zip on GitHub Releases and through the Homebrew tap.

## One-time setup

1. **Apple Developer membership.** It must be active to create certificates and notarize.
2. **Developer ID certificate.** In Xcode: Settings → Accounts → select your team → Manage
   Certificates → **+** → **Developer ID Application**. Then find its exact name:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

3. **Notarization credentials.** Create an app-specific password at
   [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific
   Passwords, then save it to the keychain under the profile name `hautekey`:

   ```sh
   xcrun notarytool store-credentials hautekey \
       --apple-id <your Apple ID email> --team-id <TEAMID> --password <app-specific password>
   ```

4. **GitHub CLI**, signed in: `brew install gh && gh auth login`.
5. **Homebrew tap.** A public repo named `joshtronic/homebrew-tap` holding
   `Casks/hautekey.rb`, copied from `packaging/hautekey.rb`.

## Cutting a release

From a clean `main`:

```sh
export DEVELOPER_ID="Developer ID Application: <Name> (<TEAMID>)"
scripts/release.sh 1.0.0
```

The script:

1. Checks that the tree is clean, you're on `main`, and `v1.0.0` doesn't exist yet.
2. Builds a universal app and stamps it with version `1.0.0` (the build number is the commit
   count).
3. Signs it with your Developer ID, with hardened runtime and a secure timestamp.
4. Notarizes it (usually a few minutes), staples the ticket, and checks it with Gatekeeper.
5. Zips it to `build/HauteKey-1.0.0.zip` and prints its SHA-256.
6. Tags `v1.0.0`, pushes the tag, and creates a **draft** GitHub Release with the zip attached.

Then:

1. Review the draft on GitHub, edit the notes, and publish it.
2. In the tap repo, set `version` and `sha256` in `Casks/hautekey.rb` to the values the script
   printed. Commit and push.
3. Check it: `brew install --cask joshtronic/tap/hautekey`.

## Trying it without a Developer ID

```sh
scripts/release.sh 1.0.0 --dry-run
```

This runs the same build, signing with the local "Haute Key Dev" certificate, and skips
notarization, tagging, and the GitHub Release. The zip is left in `build/`. It won't open on
other Macs without a Gatekeeper warning; it's only for checking the pipeline.
