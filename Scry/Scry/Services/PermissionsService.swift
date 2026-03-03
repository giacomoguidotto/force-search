import AppKit
import ApplicationServices
import Combine

final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false
    @Published private(set) var lookUpConflictDetected: Bool = false

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    private var pollTimer: Timer?

    private init() {
        checkAll()
    }

    func checkAll() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = checkInputMonitoring()
        lookUpConflictDetected = checkLookUpConflict()
    }

    /// Prompts for Accessibility access and opens the Settings pane.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Also open the pane directly so the user can find & toggle the app
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Opens System Settings → Trackpad so the user can change Look Up gesture.
    func openTrackpadSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }

    /// Prompts for Input Monitoring access and opens the Settings pane.
    func requestInputMonitoring() {
        // Register the app in the list (first call shows system prompt)
        CGRequestListenEventAccess()
        // Open the pane directly so the user can find & toggle the app
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    /// Start polling permissions every 2 seconds (for onboarding flow).
    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAll()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Private

    private func checkInputMonitoring() -> Bool {
        // CGPreflightListenEventAccess() returns true if we have input monitoring permission.
        // Available macOS 10.15+
        return CGPreflightListenEventAccess()
    }

    /// Returns true when macOS Look Up is set to fire on force-click, which conflicts with Scry.
    private func checkLookUpConflict() -> Bool {
        let trackpadDefaults = UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")
        let threeFingerTap = trackpadDefaults?.integer(forKey: "TrackpadThreeFingerTapGesture") ?? 0
        let forceClickEnabled = UserDefaults.standard.bool(forKey: "com.apple.trackpad.forceClick")

        // Conflict: force click is enabled AND Look Up uses force-click (three-finger tap gesture == 0)
        return forceClickEnabled && threeFingerTap == 0
    }
}
