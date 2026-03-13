import SwiftUI

@main
struct ScryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                onShowPreferences: { appDelegate.showPreferences() },
                onShowOnboarding: { appDelegate.showOnboarding() }
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }
}
