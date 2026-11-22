import Foundation
import HauteKeyCore

/// Settings that belong to this Mac only. Stored in UserDefaults, never in the shared config.json.
@MainActor
struct LocalSettings {
    private let defaults = UserDefaults.standard

    /// Bundle ID used by builds before 2026-11; its per-Mac settings are carried over once.
    static let legacyDomain = "dev.hautekey.app"

    static func migrateFromLegacyDomain() {
        guard let legacy = UserDefaults(suiteName: legacyDomain) else { return }
        DefaultsMigration.copyMissing(
            keys: ["showMenuBarIcon", "onboardingDone", "shownProblemIDs"], from: legacy, to: .standard
        )
    }

    var showMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "showMenuBarIcon") }
    }

    var onboardingDone: Bool {
        get { defaults.bool(forKey: "onboardingDone") }
        nonmutating set { defaults.set(newValue, forKey: "onboardingDone") }
    }

    /// Problems that already opened the settings window while the icon was hidden.
    var shownProblemIDs: [String] {
        get { defaults.stringArray(forKey: "shownProblemIDs") ?? [] }
        nonmutating set { defaults.set(newValue, forKey: "shownProblemIDs") }
    }
}
