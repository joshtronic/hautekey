# Homebrew cask for the joshtronic/homebrew-tap repo (Casks/hautekey.rb).
# After each release, set version and sha256 to what scripts/release.sh prints.
cask "hautekey" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/joshtronic/hautekey/releases/download/v#{version}/HauteKey-#{version}.zip"
  name "Haute Key"
  desc "Hyper key: tap for Spotlight, hold for apps and window snapping"
  homepage "https://github.com/joshtronic/hautekey"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "Haute Key.app"

  uninstall quit: "com.joshtronic.hautekey"

  zap trash: [
    "~/.config/hautekey",
    "~/Library/Preferences/com.joshtronic.hautekey.plist",
  ]
end
