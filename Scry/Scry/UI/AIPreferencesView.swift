import SwiftUI

struct AIPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI Analysis", isOn: $settings.aiEnabled)
            }

            if settings.aiEnabled {
                Section("Provider") {
                    Picker("Provider", selection: $settings.aiProviderType) {
                        ForEach(AIProviderType.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: settings.aiProviderType) { newValue in
                        settings.aiModel = newValue.defaultModel
                    }

                    SecureField("API Key", text: $settings.aiAPIKey)

                    TextField("Model", text: $settings.aiModel)

                    if settings.aiProviderType == .custom {
                        TextField("Endpoint URL", text: $settings.aiCustomEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Screenshot") {
                    VStack(alignment: .leading) {
                        Text("Capture region size: \(Int(settings.screenshotRegionSize))px")
                            .font(.caption)
                        Slider(
                            value: $settings.screenshotRegionSize,
                            in: Constants.Screenshot.minRegionSize...Constants.Screenshot.maxRegionSize,
                            step: 50
                        )
                    }
                }

                Section {
                    Text("API keys are stored in UserDefaults (unencrypted). Use a key with minimal permissions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
