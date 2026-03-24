import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissions = PermissionsService.shared

    var body: some View {
        Form {
            Section("Permissions") {
                permissionRow(
                    title: "Accessibility",
                    detail: "Read selected text and detect triggers",
                    granted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibility() }
                )
                permissionRow(
                    title: "Screen Recording",
                    detail: "Detect text under cursor via OCR",
                    granted: permissions.screenRecordingGranted,
                    action: { permissions.requestScreenRecording() }
                )
            }

            Section("Appearance") {
                Toggle("Show animations", isOn: $settings.showAnimations)
            }

            Section("Behavior") {
                Toggle("Dismiss panel when clicking a link", isOn: $settings.dismissOnLinkClick)

                Picker("Open links in", selection: $settings.openLinksIn) {
                    ForEach(LinkTarget.allCases, id: \.self) { target in
                        Text(target.displayName).tag(target)
                    }
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { UpdaterService.shared.automaticallyChecksForUpdates },
                    set: { UpdaterService.shared.automaticallyChecksForUpdates = $0 }
                ))

                HStack {
                    Text("Version \(UpdaterService.shared.currentVersion)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now") {
                        UpdaterService.shared.checkForUpdates()
                    }
                    .disabled(!UpdaterService.shared.canCheckForUpdates)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .onAppear { permissions.checkScreenRecording() }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") { action() }
                    .controlSize(.small)
            }
        }
    }
}
