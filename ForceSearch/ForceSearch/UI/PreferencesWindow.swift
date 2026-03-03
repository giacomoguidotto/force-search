import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)

            ProvidersPreferencesView()
                .tabItem { Label("Providers", systemImage: "magnifyingglass") }
                .tag(1)

            ShortcutsPreferencesView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(2)
        }
        .frame(minWidth: 500, minHeight: 400)
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
        panel.nameFieldStringValue = "ForceSearch-settings.json"

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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.title = "ForceSearch Preferences"
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
