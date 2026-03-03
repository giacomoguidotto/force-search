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
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                permissionStep(
                    number: 1,
                    title: "Accessibility Access",
                    description: "Required to read selected text from any application.",
                    granted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibility() }
                )

                permissionStep(
                    number: 2,
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

            // Primary action button
            Button(action: {
                settings.hasCompletedOnboarding = true
                onComplete()
            }) {
                Text(permissions.allPermissionsGranted ? "Get Started" : "Continue Anyway")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 420, height: 480)
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
                    Button("Grant Permission") {
                        action()
                    }
                    .controlSize(.small)
                    .padding(.top, 4)
                } else {
                    Text("Granted")
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
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
