import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
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
    }
}
