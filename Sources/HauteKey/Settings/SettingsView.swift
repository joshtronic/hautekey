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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                problemBanner
                Group {
                    keyboardSection
                    bindingsSection
                    restoreSection
                }
                .disabled(model.configError != nil)
                thisMacSection
            }
            .padding(24)
        }
        .frame(width: 560, height: 680)
    }

    // MARK: - Sections

    @ViewBuilder private var problemBanner: some View {
        if !model.problems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.problems) { problem in
                    Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var keyboardSection: some View {
        section("Keyboard") {
            Picker("Hyper key", selection: edit(\.hyperKey)) {
                ForEach(HyperKey.allCases, id: \.self) { key in
                    Text(Self.hyperKeyNames[key]!).tag(key)
                }
            }

            HStack {
                Picker("Tap Hyper to", selection: tapKind) {
                    Text("Open Spotlight").tag(TapKind.spotlight)
                    Text("Open an app…").tag(TapKind.app)
                    Text("Press a shortcut").tag(TapKind.keys)
                }
                tapDetail
            }
            if case .spotlight = model.config.tapAction, spotlight.currentShortcut() == .disabled {
                Text("Spotlight's shortcut is turned off in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.callout).foregroundStyle(.orange)
            }

            Toggle("Caps Lock acts as Control", isOn: edit(\.capsLockToControl))
                .disabled(model.config.hyperKey == .capsLock)
            if model.config.hyperKey == .capsLock {
                Text("Caps Lock is your Hyper key").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var tapDetail: some View {
        switch model.config.tapAction {
        case .spotlight:
            EmptyView()
        case .app(let bundleID):
            Button(AppInfo.details(for: bundleID)?.name ?? "Not installed on this Mac") {
                if let id = AppInfo.chooseApp() { model.edit { $0.tapAction = .app(bundleID: id) } }
            }
        case .keys(let code, let modifiers):
            KeyRecorderField(keyCode: code == 0 && modifiers.isEmpty ? nil : code, modifiers: modifiers) { code, mods in
                model.edit { $0.tapAction = .keys(keyCode: code, modifiers: mods) }
            }
        }
    }

    private var bindingsSection: some View {
        section("Hyper + key") {
            ForEach(BindableKey.all, id: \.self) { key in
                BindingRow(key: key, binding: model.config.bindings[key]) { newBinding in
                    model.edit { $0.bindings[key] = newBinding }
                }
            }
        }
    }

    private var restoreSection: some View {
        section("Restore size") {
            Text("Where Hyper + Restore puts a window it hasn't snapped before, centered.")
                .font(.callout).foregroundStyle(.secondary)
            percentSlider("Width", \.width)
            percentSlider("Height", \.height)
        }
    }

    private var thisMacSection: some View {
        section("This Mac") {
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
            if !model.showMenuBarIcon {
                Text("Open Haute Key again (from Spotlight or Finder) to get back to Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

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
        HStack {
            Text(label).frame(width: 50, alignment: .leading)
            Slider(value: SwiftUI.Binding(
                get: { model.config.restoreSize[keyPath: path] },
                set: { value in model.edit { $0.restoreSize[keyPath: path] = (value * 20).rounded() / 20 } }
            ), in: 0.1...1.0, step: 0.05)
            Text("\(Int((model.config.restoreSize[keyPath: path] * 100).rounded()))%")
                .monospacedDigit().frame(width: 44, alignment: .trailing)
        }
    }
}
