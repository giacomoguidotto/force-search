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
        accessibilityGranted
    }

    /// Fast poll (0.3s) for onboarding, slow poll (10s) for background monitoring.
    private var pollTimer: Timer?
    private var backgroundTimer: Timer?

    private init() {
        checkAll()

        // Distributed notification: unreliable but free — use as a bonus signal.
        // Add a 200ms delay before checking (Hammerspoon pattern: TCC DB update
        // lags behind the notification).
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )

        // Background poll: catch revocation and delayed grants during normal use.
        startBackgroundPolling()
    }

    @objc private func accessibilityChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.checkAll()
        }
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

    /// Prompts for Accessibility access via the system dialog.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings → Trackpad so the user can change Look Up gesture.
    func openTrackpadSettings() {
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }

    /// Prompts for Screen Recording access and opens the Settings pane.
    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    /// Prompts for Input Monitoring access and opens the Settings pane.
    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    /// Opens System Settings → Keyboard so the user can change Globe key behavior.
    func openKeyboardSettings() {
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    // MARK: - Polling

    /// Fast poll (0.3s) for onboarding/permissions UI — matches Rectangle's approach.
    func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkAll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Slow background poll (10s) to catch permission revocation during normal use.
    private func startBackgroundPolling() {
        backgroundTimer?.invalidate()
        let timer = Timer(timeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.accessibilityGranted = self?.checkAccessibility() ?? false
        }
        RunLoop.main.add(timer, forMode: .common)
        backgroundTimer = timer
    }

    // MARK: - Private Checks

    /// Dual-check: AXIsProcessTrusted() queries TCC daemon, then probe the AX API
    /// to catch race conditions where TCC reports true but the API is actually disabled
    /// (documented on macOS Ventura with rapid toggles).
    private func checkAccessibility() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let systemWide = AXUIElementCreateSystemWide()
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedApplicationAttribute as CFString, &value)
        return result == .success || result == .noValue
    }

    /// Attempt to create a CGEvent tap — requires Input Monitoring permission.
    /// CGPreflightListenEventAccess() caches its result per-process, so we
    /// probe directly instead.
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

    /// Fresh TCC lookup via SCShareableContent (unlike CGPreflightScreenCaptureAccess
    /// which caches per-process).
    private func checkScreenRecordingAsync() {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { [weak self] content, error in
            let granted = error == nil && content != nil
            DispatchQueue.main.async {
                self?.screenRecordingGranted = granted
            }
        }
    }

    /// Globe key conflict: AppleFnUsageType 0 = Do Nothing (no conflict),
    /// 1 = Change Input Source, 2 = Show Emoji (default).
    private func checkGlobeKeyConflict() -> Bool {
        guard let defaults = UserDefaults(suiteName: "com.apple.HIToolbox") else { return true }
        let usageType = defaults.integer(forKey: "AppleFnUsageType")
        return usageType != 0
    }

    /// Look Up conflict: fires on force-click when three-finger tap is not configured.
    private func checkLookUpConflict() -> Bool {
        let trackpadDefaults = UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")
        let threeFingerTap = trackpadDefaults?.integer(forKey: "TrackpadThreeFingerTapGesture") ?? 0
        let forceClickEnabled = UserDefaults.standard.bool(forKey: "com.apple.trackpad.forceClick")
        return forceClickEnabled && threeFingerTap == 0
    }
}
