import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "HK"
let menu = NSMenu()
menu.addItem(withTitle: "Quit Haute Key", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
statusItem.menu = menu
app.run()
