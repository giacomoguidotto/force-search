import SwiftUI

struct ProvidersPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    private let registry = ProviderRegistry.shared

    var body: some View {
        Form {
            Section("Default Provider") {
                Picker("Default provider", selection: $settings.defaultProvider) {
                    ForEach(settings.providerOrder, id: \.self) { id in
                        if let provider = registry.provider(for: id) {
                            Label(provider.name, systemImage: provider.iconSymbolName).tag(id)
                        }
                    }
                }

                Toggle("Remember last-used provider", isOn: $settings.rememberLastProvider)
            }

            Section("Enabled Providers") {
                Text("Drag to reorder. Enabled providers appear as tabs in the search panel.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                List {
                    ForEach($settings.providerOrder, id: \.self) { $id in
                        if let provider = registry.provider(for: id) {
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                                Toggle(isOn: Binding(
                                    get: { settings.enabledProviders.contains(id) },
                                    set: { enabled in
                                        if enabled {
                                            if !settings.enabledProviders.contains(id) {
                                                settings.enabledProviders.append(id)
                                            }
                                        } else {
                                            settings.enabledProviders.removeAll { $0 == id }
                                        }
                                    }
                                )) {
                                    Label(provider.name, systemImage: provider.iconSymbolName)
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        settings.providerOrder.move(fromOffsets: from, toOffset: to)
                    }
                }
                .frame(minHeight: 120)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
    }
}
