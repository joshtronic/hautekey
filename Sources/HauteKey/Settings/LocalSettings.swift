import Foundation

/// Settings that belong to this Mac only. Stored in UserDefaults, never in the shared config.json.
@MainActor
struct LocalSettings {
    private let defaults = UserDefaults.standard

    var showMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "showMenuBarIcon") }
    }

    var isPaused: Bool {
        get { defaults.bool(forKey: "isPaused") }
        nonmutating set { defaults.set(newValue, forKey: "isPaused") }
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
