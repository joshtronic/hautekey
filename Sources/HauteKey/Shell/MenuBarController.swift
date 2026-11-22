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
    }

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            self.item = item
            updateIcon()
        } else if !visible, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func updateIcon() {
        let image = NSImage(systemSymbolName: "command", accessibilityDescription: "Haute Key")
        image?.isTemplate = true
        item?.button?.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(to: menu, "Settings…", #selector(openSettings), key: ",")

        let problems = model.problems
        if !problems.isEmpty {
            menu.addItem(.separator())
            for problem in problems {
                let entry = NSMenuItem(title: problem.title, action: #selector(openSettings), keyEquivalent: "")
                entry.target = self
                entry.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
                entry.toolTip = problem.message
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())
        add(to: menu, "Quit Haute Key", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    private func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = target ?? self
        // macOS 26 adds icons to common menu items; setting a real image and then nil opts out.
        entry.image = NSImage()
        entry.image = nil
        menu.addItem(entry)
    }

    @objc private func openSettings() {
        presenter.showSettings()
    }


}
