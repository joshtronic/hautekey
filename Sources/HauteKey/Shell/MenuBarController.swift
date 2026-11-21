import AppKit
import Combine

/// The menu bar icon and its menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let presenter: WindowPresenter
    private var item: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()

    init(model: AppModel, presenter: WindowPresenter) {
        self.model = model
        self.presenter = presenter
        super.init()
        model.$showMenuBarIcon
            .sink { [weak self] visible in self?.setVisible(visible) }
            .store(in: &subscriptions)
        model.$isPaused
            .sink { [weak self] paused in self?.updateIcon(paused: paused) }
            .store(in: &subscriptions)
    }

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            self.item = item
            updateIcon(paused: model.isPaused)
        } else if !visible, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func updateIcon(paused: Bool) {
        let name = paused ? "pause.circle" : "command"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Haute Key")
        image?.isTemplate = true
        item?.button?.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(to: menu, "Settings…", #selector(openSettings), key: ",")
        add(to: menu, model.isPaused ? "Resume Haute Key" : "Pause Haute Key", #selector(togglePause))
        add(to: menu, "Open Config File", #selector(openConfigFile))

        let problems = model.problems
        if !problems.isEmpty {
            menu.addItem(.separator())
            for problem in problems {
                let entry = NSMenuItem(title: "⚠︎ " + problem.message, action: nil, keyEquivalent: "")
                entry.isEnabled = false
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())
        add(to: menu, "Quit Haute Key", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    private func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = target ?? self
        menu.addItem(entry)
    }

    @objc private func openSettings() {
        presenter.showSettings()
    }

    @objc private func togglePause() {
        model.setPaused(!model.isPaused)
    }

    @objc private func openConfigFile() {
        NSWorkspace.shared.open(model.file.resolvedURL())
    }
}
