import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Haute Key needs two permissions")
                .font(.title2.bold())
            Text("Turn both on in System Settings. Haute Key starts working as soon as they're on; no restart needed.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PermissionRow(
                granted: model.hasInputMonitoring,
                name: "Input Monitoring",
                reason: "so it can see the Hyper key",
                url: Permissions.inputMonitoringSettingsURL
            )
            PermissionRow(
                granted: model.hasAccessibility,
                name: "Accessibility",
                reason: "so it can move windows",
                url: Permissions.accessibilitySettingsURL
            )

            Text("If Haute Key isn't in the list, click + and choose it from your Applications folder.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460)
    }
}

private struct PermissionRow: View {
    let granted: Bool
    let name: String
    let reason: String
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .font(.title2)
                .foregroundStyle(granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(reason).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Open System Settings") { NSWorkspace.shared.open(url) }
            }
        }
    }
}
