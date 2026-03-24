import SwiftUI

@main
struct ScryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                onShowPreferences: { appDelegate.showPreferences() }
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }
}
