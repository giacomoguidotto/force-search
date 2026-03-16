import SwiftUI

struct MenuBarView: View {
  @ObservedObject var settings = AppSettings.shared
  @ObservedObject var permissions = PermissionsService.shared
  var onShowPreferences: () -> Void
  var onShowOnboarding: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
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

      Button {
        UpdaterService.shared.checkForUpdates()
      } label: {
        Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)

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
