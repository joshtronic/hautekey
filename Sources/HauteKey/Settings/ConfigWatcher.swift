import Foundation
import HauteKeyCore

/// Watches config.json (through its symlink) and calls back when someone else changes it.
/// Watches the parent directory too, since editors often save by replacing the file.
@MainActor
final class ConfigWatcher {
    private let file: ConfigFile
    private let onChange: @MainActor () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private var lastOwnWrite: Data?

    init(file: ConfigFile, onChange: @escaping @MainActor () -> Void) {
        self.file = file
        self.onChange = onChange
    }

    func start() {
        arm()
    }

    func stop() {
        pending?.cancel()
        sources.forEach { $0.cancel() }
        sources = []
    }

    /// Tells the watcher about a save the app made itself, so it doesn't reload its own write.
    func noteOwnWrite(_ data: Data) {
        lastOwnWrite = data
    }

    private func arm() {
        stop()
        let target = file.resolvedURL()
        watch(target.path, events: [.write, .extend, .rename, .delete])
        watch(target.deletingLastPathComponent().path, events: [.write])
        if file.url.deletingLastPathComponent() != target.deletingLastPathComponent() {
            watch(file.url.deletingLastPathComponent().path, events: [.write])
        }
    }

    private func watch(_ path: String, events: DispatchSource.FileSystemEvent) {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.somethingChanged() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        sources.append(source)
    }

    private func somethingChanged() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.settle() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func settle() {
        arm()  // The file may have been replaced; watch the new one.
        if let data = try? Data(contentsOf: file.resolvedURL()), data == lastOwnWrite { return }
        onChange()
    }
}
