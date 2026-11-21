import Foundation
import Testing
@testable import HauteKeyCore

private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hautekey-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    func mkdir(_ path: String) throws {
        try FileManager.default.createDirectory(at: url(path), withIntermediateDirectories: true)
    }

    func symlink(_ path: String, to destination: String) throws {
        try FileManager.default.createSymbolicLink(atPath: url(path).path, withDestinationPath: destination)
    }

    func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url(path).path)) != nil
    }
}

private var sample: Config {
    var c = Config()
    c.bindings[BindableKey("1")!] = .app(bundleID: "org.mozilla.firefox")
    c.bindings[BindableKey("w")!] = .snap(.maximize)
    return c
}

@Test func missingFileLoadsAsMissing() throws {
    let box = try Sandbox()
    #expect(ConfigFile(url: box.url("config.json")).load() == .missing)
}

@Test func saveThenLoadRoundTrips() throws {
    let box = try Sandbox()
    let file = ConfigFile(url: box.url("nested/dir/config.json"))
    let data = try file.save(sample)
    #expect(file.load() == .loaded(sample, data))
}

@Test func saveThroughSymlinkKeepsSymlink() throws {
    let box = try Sandbox()
    try box.mkdir("dotfiles")
    try box.mkdir("home/.config/hautekey")
    let target = box.url("dotfiles/config.json")
    try ConfigCodec.encode(Config()).write(to: target)
    try box.symlink("home/.config/hautekey/config.json", to: target.path)

    try ConfigFile(url: box.url("home/.config/hautekey/config.json")).save(sample)

    #expect(box.isSymlink("home/.config/hautekey/config.json"))
    #expect(try ConfigCodec.decode(Data(contentsOf: target)) == sample)
}

@Test func danglingSymlinkLoadsAsMissingAndSaveCreatesTarget() throws {
    let box = try Sandbox()
    try box.mkdir("home")
    try box.symlink("home/config.json", to: box.url("dotfiles/nope/config.json").path)
    let file = ConfigFile(url: box.url("home/config.json"))

    #expect(file.load() == .missing)
    try file.save(sample)

    #expect(box.isSymlink("home/config.json"))
    #expect(try ConfigCodec.decode(Data(contentsOf: box.url("dotfiles/nope/config.json"))) == sample)
}

@Test func invalidFileLoadsAsFailed() throws {
    let box = try Sandbox()
    try Data("{".utf8).write(to: box.url("config.json"))
    guard case .failed(.syntax) = ConfigFile(url: box.url("config.json")).load() else {
        Issue.record("expected a syntax failure")
        return
    }
}

@Test func relativeSymlinkResolves() throws {
    let box = try Sandbox()
    try box.mkdir("dotfiles")
    try box.mkdir("home")
    try box.symlink("home/config.json", to: "../dotfiles/config.json")
    let file = ConfigFile(url: box.url("home/config.json"))

    #expect(file.resolvedURL().standardizedFileURL == box.url("dotfiles/config.json").standardizedFileURL)
    try file.save(sample)
    #expect(box.isSymlink("home/config.json"))
    #expect(FileManager.default.fileExists(atPath: box.url("dotfiles/config.json").path))
}

@Test func saveLeavesNoTempFiles() throws {
    let box = try Sandbox()
    try ConfigFile(url: box.url("config.json")).save(sample)
    #expect(try FileManager.default.contentsOfDirectory(atPath: box.root.path) == ["config.json"])
}

@Test func defaultURLIsUnderDotConfig() {
    #expect(ConfigFile.defaultURL.path.hasSuffix("/.config/hautekey/config.json"))
}
