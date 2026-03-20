import SwiftUI
import AppKit

enum PreferenceSection: String, CaseIterable, Identifiable {
    case general
    case providers
    case shortcuts
    case ai
    case console

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .shortcuts: return "Shortcuts"
        case .ai: return "AI"
        case .console: return "Console"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .providers: return "magnifyingglass"
        case .shortcuts: return "keyboard"
        case .ai: return "sparkles"
        case .console: return "ladybug"
        }
    }
}

struct PreferencesView: View {
    @State private var selectedSection: PreferenceSection = .general

    var body: some View {
        HStack(spacing: 0) {
            List(PreferenceSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(width: 170)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 500)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .general:
            GeneralPreferencesView()
        case .providers:
            ProvidersPreferencesView()
        case .shortcuts:
            ShortcutsPreferencesView()
        case .ai:
            AIPreferencesView()
        case .console:
            DebugConsoleView()
        }
    }
}

final class PreferencesWindowController: NSObject {
    private var window: NSWindow?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = PreferencesView()
        let hostingView = NSHostingView(rootView: prefsView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.title = "Scry Preferences"
        win.appearance = NSAppearance(named: .darkAqua)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        AppActivationPolicy.updatePolicy()
    }
}
