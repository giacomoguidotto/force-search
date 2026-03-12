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
        NavigationSplitView {
            List(PreferenceSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
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
        .frame(minWidth: 680, minHeight: 500)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                Menu {
                    Button("Export Settings...") { exportSettings() }
                    Button("Import Settings...") { importSettings() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func exportSettings() {
        guard let data = AppSettings.shared.exportSettings() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Scry-settings.json"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { result in
            if result == .OK, let url = panel.url,
               let data = try? Data(contentsOf: url) {
                _ = AppSettings.shared.importSettings(from: data)
            }
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
