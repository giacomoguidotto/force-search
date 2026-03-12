import ApplicationServices
import SwiftUI

struct DebugConsoleView: View {
    @ObservedObject var log = DebugLogStore.shared
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var autoScroll = true
    @State private var refreshID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Status summary
            DisclosureGroup("Status") {
                VStack(alignment: .leading, spacing: 4) {
                    statusRow("Accessibility", permissions.accessibilityGranted)
                    statusRow("Input Monitoring", permissions.inputMonitoringGranted)
                    statusRow("Screen Recording", permissions.screenRecordingGranted)
                    statusRow("AXIsProcessTrusted()", AXIsProcessTrusted())
                    Divider()
                    keyValue("Force Click", settings.forceClickEnabled ? "Enabled" : "Disabled")
                    keyValue("Global Hotkey", settings.hotKeyEnabled ? "Enabled" : "Disabled")
                    keyValue("Pressure threshold", String(format: "%.2f", settings.pressureSensitivity))
                    keyValue("Event tap", log.eventTapStatus)
                    Divider()
                    Button("Refresh") {
                        permissions.checkAll()
                        refreshID = UUID()
                    }
                    .controlSize(.small)
                }
                .font(.system(.caption, design: .monospaced))
                .id(refreshID)
            }
            .padding(8)

            Divider()

            // Log toolbar
            HStack(spacing: 6) {
                Text("Event Log (\(log.filteredEntries.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()

                Picker("Level", selection: $log.filterLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .fixedSize()

                Button("Copy All") { copyAll() }
                    .font(.caption)
                    .controlSize(.small)
                Button("Clear") { log.clear() }
                    .font(.caption)
                    .controlSize(.small)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Log entries
            ScrollViewReader { proxy in
                List(log.filteredEntries) { entry in
                    logRow(entry)
                        .id(entry.id)
                        .contextMenu {
                            Button("Copy Line") {
                                copyToClipboard(entry.formatted)
                            }
                        }
                }
                .listStyle(.plain)
                .onChange(of: log.filteredEntries.count) { _ in
                    if autoScroll, let last = log.filteredEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { permissions.checkAll() }
    }

    private func logRow(_ entry: DebugLogStore.Entry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(entry.level.label)
                .foregroundColor(colorForLevel(entry.level))
                .fontWeight(.medium)
                .frame(width: 45, alignment: .leading)
            Text(entry.category)
                .foregroundColor(colorForCategory(entry.category))
                .frame(width: 80, alignment: .leading)
            Text(entry.message)
        }
        .font(.system(.caption, design: .monospaced))
    }

    private func copyAll() {
        copyToClipboard(log.formattedAll)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func statusRow(_ label: String, _ granted: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
            Text(granted ? "Yes" : "No")
                .fontWeight(.medium)
        }
    }

    private func keyValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Tap", "Passive": return .blue
        case "EventTap": return .orange
        case "Search": return .green
        case "TextExtractor": return .purple
        default: return .primary
        }
    }
}
