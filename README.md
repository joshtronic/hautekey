# Haute Key

A Hyper key for your Mac.

- **Tap** the Hyper key (right ⌘ by default) to open Spotlight.
- **Hyper + 0–9 / A–Z** opens an app or snaps the front window.
- Default snaps: **W** maximize, **A** left half, **D** right half, **S** restore.

One small menu bar app. No Karabiner, no kernel extensions, no subscription.

## Why this exists

I bounce between GNOME and macOS, and GNOME gets one thing exactly right: the Super key.
Tap it and you're searching, so you type an app name and hit Enter. Hold it and press
a number to jump to an app in the dock, or press a direction to snap the window. Back in
2012 I described Activities as "one key, one place, do it all." I map Super to the
*right-hand* Super key, because otherwise
["I'd probably never touch that key"](https://joshtronic.com/2018/09/09/why-i-dont-use-a-tiling-window-manager/).

I've been trying to get that same muscle memory on a Mac for over a decade:

- **2014:** Alfred for launching, and Spectacle to
  ["place windows with hot keys not unlike how xmonad works"](https://joshtronic.com/2014/07/20/tools-of-the-trade-2014/).
- **2016:** Hammerspoon to bind modifier+number to my most-used apps, inspired by picking
  weapons in Doom and Quake
  ([Fastest way to switch between apps](https://joshtronic.com/2016/04/03/fastest-way-to-switch-between-apps/)).
  Then Karabiner, so tapping **right ⌘** opened the launcher and right ⌘+number opened apps
  ([Leveraging the power of the right command key in OS X](https://joshtronic.com/2016/06/05/leveraging-the-power-of-the-right-command-key-in-os-x/)).
- **Later in 2016:** a macOS update broke Karabiner, and
  ["this reliance on third-party hackery"](https://joshtronic.com/2016/10/16/switching-from-mac-os-x-back-to-linux-part-1/)
  sent me back to Linux, where window snapping and app hotkeys are built in.
- **2024:** back on a Mac, I tried Hyperkey with Hammerspoon, then Caps Lock as Hyper, and
  landed on Karabiner-Elements plus Raycast. Right ⌘ tapped opens the launcher, right ⌘+1–9
  opens apps, and right ⌘+WASD snaps windows, just like GNOME's Super+WASD
  ([My quest to align hotkeys on macOS and GNOME](https://joshtronic.com/2024/11/10/align-hotkeys-macos-gnome/)).

That last setup worked, but it took two apps, and Raycast was doing very little. I don't need
a launcher with extensions. Spotlight is closer to how GNOME's search works anyway. Then Raycast
put window snapping behind a subscription, so I was paying yearly for a few hotkeys.

Haute Key is that whole setup in one app: the right ⌘ key as Super, Spotlight on tap, apps on
numbers, and windows on WASD. No Karabiner, no Hammerspoon, no subscription.

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

## Support

Haute Key is free and always will be. If it saves you a subscription, you can
[sponsor me on GitHub](https://github.com/sponsors/joshtronic). Totally optional, and much appreciated.

## License

GPL-3.0. See [LICENSE](LICENSE).
