import HauteKeyCore
import SwiftUI

/// One key's row in Settings: the key, what it does, and a menu to change it.
struct BindingRow: View {
    let key: BindableKey
    let binding: KeyBinding?
    let onChange: (KeyBinding?) -> Void

    private enum Choice: Hashable {
        case none, app, snap(SnapAction)
    }

    private static let snapNames: [SnapAction: String] = [
        .maximize: "Maximize", .leftHalf: "Left half", .rightHalf: "Right half", .restore: "Restore",
    ]

    var body: some View {
        HStack(spacing: 12) {
            Text(key.rawValue.uppercased())
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 28, height: 24)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            label
            Spacer()
            Picker("", selection: choice) {
                Text("None").tag(Choice.none)
                Text("App…").tag(Choice.app)
                Divider()
                ForEach(SnapAction.allCases, id: \.self) { snap in
                    Text(Self.snapNames[snap]!).tag(Choice.snap(snap))
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    @ViewBuilder private var label: some View {
        switch binding {
        case .app(let bundleID)?:
            if let details = AppInfo.details(for: bundleID) {
                Image(nsImage: details.icon).resizable().frame(width: 20, height: 20)
                Text(details.name)
            } else {
                Text("Not installed on this Mac").foregroundStyle(.secondary)
                Text(bundleID).font(.caption).foregroundStyle(.tertiary)
            }
        case .snap(let snap)?:
            Image(systemName: "rectangle.split.2x1").frame(width: 20)
            Text(Self.snapNames[snap]!)
        case nil:
            Text("—").foregroundStyle(.tertiary)
        }
    }

    private var choice: SwiftUI.Binding<Choice> {
        SwiftUI.Binding(
            get: {
                switch binding {
                case .app?: .app
                case .snap(let snap)?: .snap(snap)
                case nil: .none
                }
            },
            set: { newChoice in
                switch newChoice {
                case .none: onChange(nil)
                case .snap(let snap): onChange(.snap(snap))
                case .app:
                    if let bundleID = AppInfo.chooseApp() { onChange(.app(bundleID: bundleID)) }
                }
            }
        )
    }
}
