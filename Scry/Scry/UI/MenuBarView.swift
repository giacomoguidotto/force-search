import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissions = PermissionsService.shared
    var onShowPreferences: () -> Void
    var onShowOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            HStack {
                Circle()
                    .fill(permissions.allPermissionsGranted ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(permissions.allPermissionsGranted ? "Active" : "Permissions Required")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Trigger info
            if settings.forceClickEnabled {
                Label("Force Click to search", systemImage: "hand.tap")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            if settings.hotKeyEnabled {
                Label("Hotkey: \(settings.hotKey.displayString)", systemImage: "keyboard")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            Divider()

            // Toggles
            Toggle("Force Click", isOn: $settings.forceClickEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            Toggle("Global Hotkey", isOn: $settings.hotKeyEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            Divider()

            // Actions
            Button(action: onShowPreferences) {
                Label("Preferences...", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !permissions.allPermissionsGranted {
                Button(action: onShowOnboarding) {
                    Label("Setup Permissions...", systemImage: "lock.shield")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Scry", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 220)
    }
}
