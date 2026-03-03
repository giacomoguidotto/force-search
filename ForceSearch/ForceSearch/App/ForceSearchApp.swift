import SwiftUI

@main
struct ForceSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                onShowPreferences: { appDelegate.showPreferences() },
                onShowOnboarding: { appDelegate.showOnboarding() }
            )
        } label: {
            Image(systemName: AppSettings.shared.menuBarIconStyle.symbolName)
        }
    }
}
