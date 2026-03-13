import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var settings = AppSettings.shared
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image("ScryIcon")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(settings.hasCompletedOnboarding ? "Scry" : "Welcome to Scry")
                    .font(.title.bold())
                Text(settings.hasCompletedOnboarding
                     ? "A permission needs your attention"
                     : "Just a few steps to unlock instant search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                permissionStep(
                    number: 1,
                    title: "Disable Look Up",
                    description: "macOS Look Up uses force-click by default, which conflicts with Scry. Change it to three-finger tap or disable it.",
                    granted: !permissions.lookUpConflictDetected,
                    buttonLabel: "Open Trackpad Settings",
                    resolvedLabel: "No conflict",
                    action: { permissions.openTrackpadSettings() }
                )

                if showGlobeStep {
                    permissionStep(
                        number: 2,
                        title: "Globe Key",
                        // swiftlint:disable:next line_length
                        description: "The Globe key triggers Emoji or Input Source by default. Set \u{201C}Press Globe key\u{201D} to \u{201C}Do Nothing\u{201D} in System Settings \u{2192} Keyboard so Scry can use it.",
                        granted: !permissions.globeKeyConflict,
                        buttonLabel: "Open Keyboard Settings",
                        resolvedLabel: "Ready",
                        action: { permissions.openKeyboardSettings() }
                    )
                }

                permissionStep(
                    number: showGlobeStep ? 3 : 2,
                    title: "Accessibility Access",
                    description: "Required to read selected text from any application.",
                    granted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibility() }
                )

                permissionStep(
                    number: showGlobeStep ? 4 : 3,
                    title: "Input Monitoring",
                    description: "Required to detect force-click gestures on the trackpad.",
                    granted: permissions.inputMonitoringGranted,
                    action: { permissions.requestInputMonitoring() }
                )
            }
            .padding(24)

            Spacer()

            // Note
            if !permissions.allPermissionsGranted {
                Text("You may need to restart Scry after granting permissions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }

            // Primary action button — only available when all permissions are granted
            if permissions.allPermissionsGranted {
                Button {
                    settings.hasCompletedOnboarding = true
                    onComplete()
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 580)
        .onAppear {
            permissions.checkAll()
            permissions.startPolling()
        }
        .onDisappear {
            permissions.stopPolling()
        }
    }

    /// Show the Globe key step only when Globe is the active modifier and the system action conflicts.
    private var showGlobeStep: Bool {
        settings.doubleTapEnabled && settings.doubleTapModifier == .globe
    }

    @ViewBuilder
    private func permissionStep(
        number: Int,
        title: String,
        description: String,
        granted: Bool,
        buttonLabel: String = "Grant Permission",
        resolvedLabel: String = "Granted",
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(granted ? Color.green : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                if granted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !granted {
                    Button(buttonLabel) {
                        action()
                    }
                    .controlSize(.small)
                    .padding(.top, 4)
                } else {
                    Text(resolvedLabel)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
        }
    }
}

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var keyMonitor: Any?

    func showIfNeeded() {
        guard !AppSettings.shared.hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView {
            self.window?.close()
        }

        let hostingView = NSHostingView(rootView: onboardingView)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.title = "Scry Setup"
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
        startKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        stopKeyMonitor()
        window = nil
        AppActivationPolicy.updatePolicy()
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command, event.keyCode == 43 { // kVK_ANSI_Comma
                AppDelegate.shared?.showPreferences()
                return nil
            }
            return event
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
