import SwiftUI

struct AIPreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var ollamaService = OllamaService.shared
    @ObservedObject var modelListService = ModelListService.shared

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
                        modelListService.clearCache()
                        if newValue == .ollama {
                            Task {
                                await ollamaService.refreshModels()
                                selectFirstOllamaModelIfNeeded()
                            }
                        } else if newValue == .claude || newValue == .openai {
                            fetchModelsIfNeeded()
                        }
                    }

                    if settings.aiProviderType == .ollama {
                        ollamaSection
                    } else {
                        SecureField("API Key", text: $settings.aiAPIKey)
                            .onChange(of: settings.aiAPIKey) { _ in
                                modelListService.clearCache()
                                fetchModelsIfNeeded()
                            }

                        switch settings.aiProviderType {
                        case .claude, .openai:
                            modelPicker
                        case .custom:
                            TextField("Model", text: $settings.aiModel)
                            TextField("Endpoint URL", text: $settings.aiCustomEndpoint)
                                .textFieldStyle(.roundedBorder)
                        case .ollama:
                            EmptyView()
                        }
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

                if settings.aiProviderType != .ollama {
                    Section {
                        Text("API keys are stored in UserDefaults (unencrypted). Use a key with minimal permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if settings.aiProviderType == .ollama {
                Task {
                    await ollamaService.refreshModels()
                    selectFirstOllamaModelIfNeeded()
                }
            } else if settings.aiProviderType == .claude || settings.aiProviderType == .openai {
                fetchModelsIfNeeded()
            }
        }
    }

    // MARK: - Model Picker (Claude / OpenAI)

    @ViewBuilder
    private var modelPicker: some View {
        if modelListService.isLoading {
            HStack {
                Text("Model")
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        } else if modelListService.models.isEmpty {
            HStack {
                TextField("Model", text: $settings.aiModel)
                Button {
                    fetchModelsIfNeeded(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            if let error = modelListService.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !settings.aiAPIKey.isEmpty {
                Text("Enter a valid API key to load models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack {
                Picker("Model", selection: $settings.aiModel) {
                    ForEach(modelListService.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                Button {
                    fetchModelsIfNeeded(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func fetchModelsIfNeeded(force: Bool = false) {
        let provider = settings.aiProviderType
        let apiKey = settings.aiAPIKey
        guard !apiKey.isEmpty, provider == .claude || provider == .openai else { return }
        if force { modelListService.clearCache() }
        Task {
            await modelListService.fetchModels(for: provider, apiKey: apiKey)
            selectFirstModelIfNeeded()
        }
    }

    private func selectFirstModelIfNeeded() {
        let models = modelListService.models
        if !models.isEmpty, !models.contains(settings.aiModel) {
            settings.aiModel = models.first(where: {
                $0 == settings.aiProviderType.defaultModel
            }) ?? models[0]
        }
    }

    // MARK: - Ollama Section

    @ViewBuilder
    private var ollamaSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ollamaStatusColor)
                .frame(width: 8, height: 8)
            Text(ollamaService.status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if ollamaService.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await ollamaService.refreshModels() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(ollamaService.isLoading)
        }

        if ollamaService.status == .notRunning {
            Label("Start Ollama with `ollama serve`", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.orange)
        }

        if ollamaService.availableModels.isEmpty {
            if ollamaService.status == .running {
                Label(
                    "No models found. Pull one with `ollama pull llama3.2`",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        } else {
            Picker("Model", selection: $settings.aiModel) {
                ForEach(ollamaService.availableModels) { model in
                    HStack {
                        Text(model.name)
                        if model.supportsVision {
                            Image(systemName: "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(model.name)
                }
            }
        }

        if !ollamaService.availableModels.isEmpty,
           !ollamaService.modelSupportsVision(settings.aiModel) {
            Label(
                "This model does not support images. Screenshots will not be sent.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundColor(.orange)
        }
    }

    private func selectFirstOllamaModelIfNeeded() {
        let models = ollamaService.availableModels
        if !models.isEmpty, !models.contains(where: { $0.name == settings.aiModel }) {
            settings.aiModel = models[0].name
        }
    }

    private var ollamaStatusColor: Color {
        switch ollamaService.status {
        case .running: return .green
        case .notRunning: return .red
        case .error: return .red
        case .unknown: return .gray
        }
    }
}
