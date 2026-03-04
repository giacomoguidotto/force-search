import SwiftUI

@main
struct ScryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                onShowPreferences: { appDelegate.showPreferences() },
                onShowOnboarding: { appDelegate.showOnboarding() },
                onShowDebugConsole: { appDelegate.showDebugConsole() }
            )
        } label: {
            Image(systemName: AppSettings.shared.menuBarIconStyle.symbolName)
        }
    }
}
