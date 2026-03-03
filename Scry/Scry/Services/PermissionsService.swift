import AppKit
import ApplicationServices
import Combine

final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false

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
    }

    /// Opens System Settings to the Accessibility pane for this app.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Requests Input Monitoring permission. This calls CGRequestListenEventAccess()
    /// which registers the app in System Settings > Privacy > Input Monitoring and
    /// shows a system prompt on first call.
    func requestInputMonitoring() {
        CGRequestListenEventAccess()
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
}
