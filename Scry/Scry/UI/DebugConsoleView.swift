import ApplicationServices
import SwiftUI

struct DebugConsoleView: View {
    @ObservedObject var log = DebugLogStore.shared
    @ObservedObject var permissions = PermissionsService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var autoScroll = true
    @State private var showStatus = true
    @State private var refreshID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // ── Status Panel ──
            statusPanel
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // ── Log Toolbar ──
            logToolbar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // ── Separator ──
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // ── Log Entries ──
            logList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { permissions.checkAll() }
    }

    // MARK: - Status Panel

    private var statusPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showStatus.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(showStatus ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: showStatus)
                            .frame(width: 12)
                        Text("Status")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ScryTheme.Colors.textPrimaryColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if showStatus {
                    Button {
                        permissions.checkAll()
                        refreshID = UUID()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .medium))
                            Text("Refresh")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(ScryTheme.Colors.accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if showStatus {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)

                    // Permissions grid
                    VStack(spacing: 0) {
                        permissionRow("Accessibility", permissions.accessibilityGranted)
                        permissionRow("Input Monitoring", permissions.inputMonitoringGranted)
                        permissionRow("Screen Recording", permissions.screenRecordingGranted)
                        permissionRow("AXIsProcessTrusted()", AXIsProcessTrusted())
                    }
                    .padding(.vertical, 6)

                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)

                    // Configuration
                    VStack(spacing: 0) {
                        configRow("Force Click", settings.forceClickEnabled ? "Enabled" : "Disabled")
                        configRow("Global Hotkey", settings.hotKeyEnabled ? "Enabled" : "Disabled")
                        configRow("Pressure threshold", String(format: "%.2f", settings.pressureSensitivity))
                        configRow("Event tap", log.eventTapStatus)
                    }
                    .padding(.vertical, 6)
                }
                .id(refreshID)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Log Toolbar

    private var logToolbar: some View {
        HStack(spacing: 8) {
            Text("Event Log")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ScryTheme.Colors.textPrimaryColor)

            Text("\(log.filteredEntries.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(ScryTheme.Colors.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(ScryTheme.Colors.accentColor.opacity(0.12))
                )

            Spacer()

            Picker("Level", selection: $log.filterLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)

            Spacer()

            Toggle(isOn: $autoScroll) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10))
            }
            .toggleStyle(.checkbox)
            .help("Auto-scroll")

            Button(action: copyAll) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Copy All")

            Button {
                log.clear()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Clear")
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            List(log.filteredEntries) { entry in
                logRow(entry)
                    .id(entry.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button("Copy Line") {
                            copyToClipboard(entry.formatted)
                        }
                    }
            }
            .listStyle(.plain)
            .layoutPriority(1)
            .onChange(of: log.filteredEntries.count) { _ in
                if autoScroll, let last = log.filteredEntries.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Row Views

    private func permissionRow(_ label: String, _ granted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ScryTheme.Colors.textSecondaryColor)
            Spacer()
            Circle()
                .fill(granted ? Color.green : Color.red.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(granted ? "Yes" : "No")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(granted ? .green : .red.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func configRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ScryTheme.Colors.textSecondaryColor)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(ScryTheme.Colors.textPrimaryColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func logRow(_ entry: DebugLogStore.Entry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                .foregroundColor(ScryTheme.Colors.textTertiaryColor)
                .frame(width: 86, alignment: .leading)

            Text(entry.level.label)
                .foregroundColor(colorForLevel(entry.level))
                .fontWeight(.semibold)
                .frame(width: 42, alignment: .leading)

            Text(entry.category)
                .foregroundColor(colorForCategory(entry.category))
                .frame(width: 76, alignment: .leading)

            Text(entry.message)
                .foregroundColor(ScryTheme.Colors.textPrimaryColor)
                .lineLimit(3)
        }
        .font(.system(size: 11, design: .monospaced))
    }

    // MARK: - Actions

    private func copyAll() {
        copyToClipboard(log.formattedAll)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Colors

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
