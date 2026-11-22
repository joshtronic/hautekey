import Foundation

/// Reads and writes `config.json`. If the path is a symlink (for example into dotfiles),
/// reads and writes go to the symlink's target and the symlink itself is left alone.
public struct ConfigFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/hautekey/config.json")
    }

    public enum LoadResult: Equatable, Sendable {
        case missing
        case loaded(Config, Data)
        case failed(ConfigError)
    }

    /// The file the symlink chain ends at. Works even when that file doesn't exist yet.
    public func resolvedURL() -> URL {
        var current = url
        for _ in 0..<16 {
            guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: current.path) else {
                break
            }
            current = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : current.deletingLastPathComponent().appendingPathComponent(destination)
        }
        return current
    }

    public func load() -> LoadResult {
        let target = resolvedURL()
        guard FileManager.default.fileExists(atPath: target.path) else { return .missing }
        let data: Data
        do {
            data = try Data(contentsOf: target)
        } catch {
            return .failed(.syntax(line: nil, message: "Couldn't read \(target.path): \(error.localizedDescription)"))
        }
        do {
            return .loaded(try ConfigCodec.decode(data), data)
        } catch {
            return .failed(error)
        }
    }

    /// The file's text as-is, even if it isn't valid. nil when there's no file.
    public func rawText() -> String? {
        try? String(contentsOf: resolvedURL(), encoding: .utf8)
    }

    /// Encodes and writes atomically; returns the bytes written.
    @discardableResult
    public func save(_ config: Config) throws -> Data {
        let data = ConfigCodec.encode(config)
        try write(data)
        return data
    }

    /// Writes bytes exactly as given, atomically (temp file + rename in the target's directory).
    public func write(_ data: Data) throws {
        let target = resolvedURL()
        let directory = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let temp = directory.appendingPathComponent(".\(target.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: temp)
        guard rename(temp.path, target.path) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: temp)
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSFilePathErrorKey: target.path,
                NSUnderlyingErrorKey: POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO),
            ])
        }
    }
}
