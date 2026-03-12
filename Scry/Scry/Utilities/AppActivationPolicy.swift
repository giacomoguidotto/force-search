import AppKit

/// Manages the app's activation policy so Scry appears in Cmd+Tab and the
/// Dock only while a standard window (Preferences, Onboarding) is open.
enum AppActivationPolicy {
    /// Call after any managed window closes. Switches back to `.accessory`
    /// (menu-bar-only) when no standard windows remain visible.
    static func updatePolicy() {
        let hasVisibleWindow = NSApp.windows.contains { window in
            window.isVisible
                && !window.isKind(of: NSPanel.self)
                && window.level == .normal
        }
        if !hasVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
