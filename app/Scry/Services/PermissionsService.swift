import AppKit
import ApplicationServices
import Combine
import ScreenCaptureKit

final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false
    @Published private(set) var screenRecordingGranted: Bool = false
    @Published private(set) var lookUpConflictDetected: Bool = false
    @Published private(set) var globeKeyConflict: Bool = false

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    private var pollTimer: Timer?

    private init() {
        checkAll()
    }

    func checkAll() {
        accessibilityGranted = checkAccessibility()
        inputMonitoringGranted = checkInputMonitoring()
        lookUpConflictDetected = checkLookUpConflict()
        globeKeyConflict = checkGlobeKeyConflict()
    }

    /// Check screen recording separately — SCShareableContent triggers the
    /// system permission prompt, so only call this when the user explicitly
    /// requests screen recording or when it's actually needed.
    func checkScreenRecording() {
        checkScreenRecordingAsync()
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

    /// Prompts for Screen Recording access and opens the Settings pane.
    func requestScreenRecording() {
        // Register the app in the list (first call shows system prompt on macOS 15+)
        CGRequestScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
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
        // Use .common mode so the timer fires even during modal/tracking run-loop modes.
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Private

    /// AXIsProcessTrusted() caches its result for the process lifetime.
    /// Instead, probe the accessibility API directly: query the focused
    /// application's AXUIElement for its role. A successful response means
    /// we have accessibility permission; an error means it was revoked.
    private func checkAccessibility() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &value)
        return result == .success || result == .noValue
    }

    /// CGPreflightListenEventAccess() caches its result for the process
    /// lifetime. Instead, attempt to create a default-mode event tap which
    /// requires Input Monitoring permission. If the tap is created
    /// successfully we immediately disable and release it.
    private func checkInputMonitoring() -> Bool {
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: { _, _, event, _ in Unmanaged.passRetained(event) },
            userInfo: nil
        )
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            return true
        }
        return false
    }

    /// Checks screen recording permission via SCShareableContent which performs
    /// a fresh TCC lookup on every call (unlike CGPreflightScreenCaptureAccess
    /// which caches the result for the process lifetime).
    private func checkScreenRecordingAsync() {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { [weak self] content, error in
            let granted = error == nil && content != nil
            DispatchQueue.main.async {
                self?.screenRecordingGranted = granted
            }
        }
    }

    /// Opens System Settings → Keyboard so the user can change Globe key behavior.
    func openKeyboardSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    /// Returns true when the Globe key is configured to trigger a system action
    /// (emoji picker or input source switch), which interferes with double-tap detection.
    /// AppleFnUsageType: 0 = Do Nothing, 1 = Change Input Source, 2 = Show Emoji (default).
    private func checkGlobeKeyConflict() -> Bool {
        guard let defaults = UserDefaults(suiteName: "com.apple.HIToolbox") else { return true }
        let usageType = defaults.integer(forKey: "AppleFnUsageType")
        // 0 means "Do Nothing" — no conflict
        return usageType != 0
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
