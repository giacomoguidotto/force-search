import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var settings = AppSettings.shared
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Welcome to Scry")
                    .font(.title.bold())
                Text("Replace Look Up with instant search")
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

                permissionStep(
                    number: 2,
                    title: "Accessibility Access",
                    description: "Required to read selected text from any application.",
                    granted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibility() }
                )

                permissionStep(
                    number: 3,
                    title: "Input Monitoring",
                    description: "Required to detect force-click gestures on the trackpad.",
                    granted: permissions.inputMonitoringGranted,
                    action: { permissions.requestInputMonitoring() }
                )

                permissionStep(
                    number: 4,
                    title: "Screen Recording",
                    description: "Required for screenshot-based text extraction via OCR.",
                    granted: permissions.screenRecordingGranted,
                    action: { permissions.requestScreenRecording() }
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

final class OnboardingWindowController {
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AppSettings.shared.hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let onboardingView = OnboardingView {
            self.window?.close()
            self.window = nil
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
        win.makeKeyAndOrderFront(nil)

        self.window = win
    }
}
