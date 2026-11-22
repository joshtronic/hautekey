import HauteKeyCore
import SwiftUI

enum SnapLabels {
    static func name(_ snap: SnapAction) -> String {
        switch snap {
        case .maximize: "Maximize"
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .restore: "Restore"
        }
    }

    static func symbol(_ snap: SnapAction) -> String {
        switch snap {
        case .maximize: "rectangle.inset.filled"
        case .leftHalf: "rectangle.lefthalf.inset.filled"
        case .rightHalf: "rectangle.righthalf.inset.filled"
        case .restore: "rectangle.center.inset.filled"
        }
    }
}

/// The choices for what a key does, shared by the edit menu and the Add Shortcut menu.
struct BindingChoices: View {
    let onChoose: (KeyBinding) -> Void

    var body: some View {
        Button("App…") {
            if let bundleID = AppInfo.chooseApp() { onChoose(.app(bundleID: bundleID)) }
        }
        Divider()
        ForEach(SnapAction.allCases, id: \.self) { snap in
            Button {
                onChoose(.snap(snap))
            } label: {
                Label(SnapLabels.name(snap), systemImage: SnapLabels.symbol(snap))
            }
        }
    }
}

struct KeyBadge: View {
    let key: BindableKey

    var body: some View {
        Text(key.rawValue.uppercased())
            .font(.system(.callout, design: .monospaced).bold())
            .frame(width: 24, height: 22)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// One bound key in Settings: the key, what it does, and a menu to change or remove it.
struct BindingRow: View {
    let key: BindableKey
    let binding: KeyBinding
    let onChange: (KeyBinding?) -> Void

    var body: some View {
        HStack(spacing: 10) {
            KeyBadge(key: key)
            label
            Spacer()
            Menu {
                BindingChoices { onChange($0) }
                Divider()
                Button("Remove", role: .destructive) { onChange(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    @ViewBuilder private var label: some View {
        switch binding {
        case .app(let bundleID):
            if let details = AppInfo.details(for: bundleID) {
                Image(nsImage: details.icon).resizable().frame(width: 18, height: 18)
                Text(details.name)
            } else {
                Image(systemName: "questionmark.app.dashed").frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Not installed on this Mac").foregroundStyle(.secondary)
                    Text(bundleID).font(.caption).foregroundStyle(.tertiary)
                }
            }
        case .snap(let snap):
            Image(systemName: SnapLabels.symbol(snap)).frame(width: 18)
            Text(SnapLabels.name(snap))
        }
    }
}

/// "Add Shortcut" menu: pick a free key, then what it does.
struct AddBindingMenu: View {
    let freeKeys: [BindableKey]
    let onAdd: (BindableKey, KeyBinding) -> Void

    var body: some View {
        Menu {
            ForEach(freeKeys, id: \.self) { key in
                Menu("Hyper + \(key.rawValue.uppercased())") {
                    BindingChoices { onAdd(key, $0) }
                }
            }
        } label: {
            Label("Add Shortcut", systemImage: "plus")
        }
        .fixedSize()
        .disabled(freeKeys.isEmpty)
    }
}
