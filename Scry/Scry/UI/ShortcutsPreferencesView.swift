import SwiftUI

struct ShortcutsPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var recordedKeyCombo: KeyCombo?

    /// Computed hold duration matching EventTapService.requiredHoldDuration().
    private var holdDuration: Double {
        let sensitivity = settings.pressureSensitivity
        let minDelay = 0.3
        let maxDelay = 0.8
        return minDelay + (1.0 - sensitivity) * (maxDelay - minDelay)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Force Click", isOn: $settings.forceClickEnabled)

                if settings.forceClickEnabled {
                    HStack {
                        Text("Sensitivity")
                        Slider(value: $settings.pressureSensitivity, in: 0.1...1.0, step: 0.05)
                        Text("\(Int(settings.pressureSensitivity * 100))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        statRow("Hold time", String(format: "%.2fs", holdDuration))
                        statRow("Max drift", "4pt")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } header: {
                Label("Force Click", systemImage: "hand.tap")
            }

            Section {
                Toggle("Enable Global Hotkey", isOn: $settings.hotKeyEnabled)

                if settings.hotKeyEnabled {
                    HStack {
                        Text("Search hotkey")
                        Spacer()
                        HotKeyRecorderView(keyCombo: $settings.hotKey)
                            .frame(width: 160, height: 28)
                    }
                }
            } header: {
                Label("Global Hotkey", systemImage: "keyboard")
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    shortcutRow("Force Click", "Force-click on selected text")
                    shortcutRow(settings.hotKey.displayString, "Global search hotkey")
                    shortcutRow("⎋", "Close panel")
                    shortcutRow("⌘1–9", "Switch provider tabs")
                    shortcutRow("⌘↩", "Open in browser")
                    shortcutRow("⌘C", "Copy URL")
                    shortcutRow("⌘,", "Open preferences")
                    shortcutRow("⌘⌫", "Clear search field")
                    shortcutRow("↩", "Search with current text")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func shortcutRow(_ key: String, _ description: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

/// A simple hotkey recorder view — click to start recording, press keys, click again to stop.
struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var keyCombo: KeyCombo

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let view = HotKeyRecorderNSView()
        view.keyCombo = keyCombo
        view.onKeyComboChanged = { newCombo in
            keyCombo = newCombo
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        nsView.keyCombo = keyCombo
        nsView.updateDisplay()
    }
}

final class HotKeyRecorderNSView: NSView {
    var keyCombo: KeyCombo = .default
    var onKeyComboChanged: ((KeyCombo) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false
    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        stopRecording()
    }

    func updateDisplay() {
        if isRecording {
            label.stringValue = "Press keys..."
            label.textColor = .controlAccentColor
        } else {
            label.stringValue = keyCombo.displayString
            label.textColor = .labelColor
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)

        updateDisplay()
    }

    @objc private func clicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        updateDisplay()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Need at least one modifier
            guard !flags.isEmpty else { return event }

            let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: flags)
            self.keyCombo = newCombo
            self.onKeyComboChanged?(newCombo)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        updateDisplay()
    }
}
