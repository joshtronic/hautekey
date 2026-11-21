# Haute Key

A Hyper key for your Mac.

- **Tap** the Hyper key (right ⌘ by default) to open Spotlight.
- **Hyper + 0–9 / A–Z** opens an app or snaps the front window.
- Default snaps: **W** maximize, **A** left half, **D** right half, **S** restore.

One small menu bar app. No Karabiner, no kernel extensions, no subscription.

## Requirements

- macOS 15 or later
- Xcode installed and selected (`sudo xcode-select -s /Applications/Xcode.app`)

## Setup (once)

```sh
scripts/create-dev-cert.sh
```

This creates a local "Haute Key Dev" code-signing certificate, so macOS keeps the app's
permissions when you rebuild. macOS asks for your password to trust it.

## Build and install

```sh
scripts/build-app.sh --open
```

This builds, signs, and installs `~/Applications/Haute Key.app`, then launches it.

Run the tests with `swift test`.

## Permissions

Haute Key needs two permissions in **System Settings → Privacy & Security**:

- **Input Monitoring:** to see the Hyper key.
- **Accessibility:** to move windows.

If Haute Key isn't in a list, click **+** and choose it from `~/Applications`.

## Configuration

Settings live in `~/.config/hautekey/config.json`. You can edit them in the app or by hand,
and changes apply live. The file can be a symlink, for example into your dotfiles.

## Uninstall

Quit Haute Key, delete the app, and reset the key mapping (quitting already does this):

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

## License

GPL-3.0. See [LICENSE](LICENSE).
