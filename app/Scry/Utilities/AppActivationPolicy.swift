import AppKit

/// Manages the app's activation policy so Scry appears in Cmd+Tab and the
/// Dock only while a standard window (Preferences, Onboarding) is open.
enum AppActivationPolicy {
    /// Titles of windows that should keep the app in Cmd+Tab.
    private static let managedTitles: Set<String> = ["Scry Preferences", "Scry Setup"]

    /// Call after any managed window closes. Switches back to `.accessory`
    /// (menu-bar-only) when no managed windows remain visible.
    static func updatePolicy() {
        let hasManaged = NSApp.windows.contains { window in
            window.isVisible && managedTitles.contains(window.title)
        }
        if !hasManaged {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
