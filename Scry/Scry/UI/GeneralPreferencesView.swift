import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissions = PermissionsService.shared

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Show animations", isOn: $settings.showAnimations)

                Picker("Menu bar icon", selection: $settings.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Label(style.rawValue.capitalized, systemImage: style.symbolName).tag(style)
                    }
                }
            }

            Section("Panel Size") {
                HStack {
                    Text("Width")
                    Slider(value: $settings.panelWidth, in: Constants.Panel.minWidth...Constants.Panel.maxWidth, step: 10)
                    Text("\(Int(settings.panelWidth))pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("Height")
                    Slider(value: $settings.panelHeight, in: Constants.Panel.minHeight...Constants.Panel.maxHeight, step: 10)
                    Text("\(Int(settings.panelHeight))pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("Opacity")
                    Slider(value: $settings.panelOpacity, in: 0.5...1.0, step: 0.05)
                    Text("\(Int(settings.panelOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
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
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            }

            Section("Permissions") {
                permissionRow("Accessibility Access", granted: permissions.accessibilityGranted)
                permissionRow("Input Monitoring", granted: permissions.inputMonitoringGranted)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .onAppear { permissions.checkAll() }
    }

    private func permissionRow(_ title: String, granted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Label("Not Granted", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}
