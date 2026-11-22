import Foundation
import Testing
@testable import HauteKeyCore

private func freshDefaults() -> (UserDefaults, String) {
    let name = "hautekey-tests-\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
}

@Test func copiesKeysMissingFromTheNewDomain() {
    let (old, oldName) = freshDefaults()
    let (new, newName) = freshDefaults()
    defer { old.removePersistentDomain(forName: oldName); new.removePersistentDomain(forName: newName) }
    old.set(false, forKey: "showMenuBarIcon")
    old.set(true, forKey: "onboardingDone")

    DefaultsMigration.copyMissing(keys: ["showMenuBarIcon", "onboardingDone", "absent"], from: old, to: new)

    #expect(new.object(forKey: "showMenuBarIcon") as? Bool == false)
    #expect(new.object(forKey: "onboardingDone") as? Bool == true)
    #expect(new.object(forKey: "absent") == nil)
}

@Test func neverOverwritesExistingValues() {
    let (old, oldName) = freshDefaults()
    let (new, newName) = freshDefaults()
    defer { old.removePersistentDomain(forName: oldName); new.removePersistentDomain(forName: newName) }
    old.set(false, forKey: "showMenuBarIcon")
    new.set(true, forKey: "showMenuBarIcon")

    DefaultsMigration.copyMissing(keys: ["showMenuBarIcon"], from: old, to: new)

    #expect(new.object(forKey: "showMenuBarIcon") as? Bool == true)
}
