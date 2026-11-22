import HauteKeyCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let spotlight: SpotlightLauncher

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private enum TapKind: Hashable { case spotlight, app, keys }

    private static let hyperKeyNames: [HyperKey: String] = [
        .rightCommand: "Right ⌘ Command", .rightOption: "Right ⌥ Option",
        .rightControl: "Right ⌃ Control", .capsLock: "Caps Lock",
    ]

    var body: some View {
        Form {
            if !model.problems.isEmpty {
                Section {
                    ForEach(model.problems) { problem in
                        Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Group {
                keyboardSection
                shortcutsSection
                restoreSection
            }
            .disabled(model.configError != nil)
            thisMacSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 420, idealHeight: 640)
    }

    // MARK: - Sections

    private var keyboardSection: some View {
        Section("Keyboard") {
            Picker("Hyper key", selection: edit(\.hyperKey)) {
                ForEach(HyperKey.allCases, id: \.self) { key in
                    Text(Self.hyperKeyNames[key]!).tag(key)
                }
            }

            Picker("Tap Hyper to", selection: tapKind) {
                Text("Open Spotlight").tag(TapKind.spotlight)
                Text("Open an app").tag(TapKind.app)
                Text("Press a shortcut").tag(TapKind.keys)
            }
            tapDetail

            Toggle("Caps Lock acts as Control", isOn: edit(\.capsLockToControl))
                .disabled(model.config.hyperKey == .capsLock)
                .help(model.config.hyperKey == .capsLock ? "Caps Lock is your Hyper key" : "")
        }
    }

    @ViewBuilder private var tapDetail: some View {
        switch model.config.tapAction {
        case .spotlight:
            if spotlight.currentShortcut() == .disabled {
                Text("Spotlight's shortcut is turned off in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.callout).foregroundStyle(.orange)
            }
        case .app(let bundleID):
            LabeledContent("App") {
                Button(AppInfo.details(for: bundleID)?.name ?? "Not installed on this Mac") {
                    if let id = AppInfo.chooseApp() { model.edit { $0.tapAction = .app(bundleID: id) } }
                }
            }
        case .keys(let code, let modifiers):
            LabeledContent("Shortcut") {
                KeyRecorderField(keyCode: code, modifiers: modifiers) { code, mods in
                    model.edit { $0.tapAction = .keys(keyCode: code, modifiers: mods) }
                }
            }
        }
    }

    private var shortcutsSection: some View {
        let bound = BindableKey.all.filter { model.config.bindings[$0] != nil }
        let free = BindableKey.all.filter { model.config.bindings[$0] == nil }
        return Section {
            ForEach(bound, id: \.self) { key in
                BindingRow(key: key, binding: model.config.bindings[key]!) { newBinding in
                    model.edit { $0.bindings[key] = newBinding }
                }
            }
            AddBindingMenu(freeKeys: free) { key, binding in
                model.edit { $0.bindings[key] = binding }
            }
        } header: {
            Text("Hyper + key")
        } footer: {
            Text("Any key 0–9 or A–Z can open an app or snap the front window.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var restoreSection: some View {
        Section {
            percentSlider("Width", \.width)
            percentSlider("Height", \.height)
        } header: {
            Text("Restore size")
        } footer: {
            Text("Where Restore puts a window it hasn't snapped before, centered.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var thisMacSection: some View {
        Section {
            Toggle("Launch at login", isOn: SwiftUI.Binding(
                get: { launchAtLogin },
                set: { enabled in
                    try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            ))
            Toggle("Show menu bar icon", isOn: SwiftUI.Binding(
                get: { model.showMenuBarIcon },
                set: { model.setShowMenuBarIcon($0) }
            ))
        } header: {
            Text("This Mac")
        } footer: {
            if !model.showMenuBarIcon {
                Text("Open Haute Key again (from Spotlight or Finder) to get back to Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    /// A SwiftUI binding that saves to config.json on every change.
    private func edit<Value>(_ path: WritableKeyPath<Config, Value>) -> SwiftUI.Binding<Value> {
        SwiftUI.Binding(
            get: { model.config[keyPath: path] },
            set: { value in model.edit { $0[keyPath: path] = value } }
        )
    }

    private var tapKind: SwiftUI.Binding<TapKind> {
        SwiftUI.Binding(
            get: {
                switch model.config.tapAction {
                case .spotlight: .spotlight
                case .app: .app
                case .keys: .keys
                }
            },
            set: { kind in
                switch kind {
                case .spotlight:
                    model.edit { $0.tapAction = .spotlight }
                case .app:
                    if let id = AppInfo.chooseApp() { model.edit { $0.tapAction = .app(bundleID: id) } }
                case .keys:
                    model.edit { $0.tapAction = .keys(keyCode: 49, modifiers: [.option]) }
                }
            }
        )
    }

    private func percentSlider(_ label: String, _ path: WritableKeyPath<RestoreSize, Double>) -> some View {
        LabeledContent(label) {
            HStack {
                Slider(value: SwiftUI.Binding(
                    get: { model.config.restoreSize[keyPath: path] },
                    set: { value in model.edit { $0.restoreSize[keyPath: path] = (value * 20).rounded() / 20 } }
                ), in: 0.1...1.0, step: 0.05)
                Text("\(Int((model.config.restoreSize[keyPath: path] * 100).rounded()))%")
                    .monospacedDigit().frame(width: 40, alignment: .trailing)
            }
        }
    }
}
