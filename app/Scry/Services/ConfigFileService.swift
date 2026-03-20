import Combine
import Foundation
import TOMLKit

final class ConfigFileService {
    static let shared = ConfigFileService(configDirectory: defaultConfigDirectory)

    let configDirectory: URL
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false
    private let debugLog = DebugLogStore.shared

    static var defaultConfigDirectory: URL {
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return URL(fileURLWithPath: xdg).appendingPathComponent("scry")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/scry")
    }

    var configFileURL: URL {
        configDirectory.appendingPathComponent("config.toml")
    }

    init(configDirectory: URL) {
        self.configDirectory = configDirectory
    }

    /// Load config file (or create initial one), then start watching for changes.
    func loadAndMigrate() {
        if let config = loadConfigFile() {
            isSyncing = true
            config.apply(to: settings)
            isSyncing = false
            debugLog.log("Config", "Loaded config from \(configFileURL.path)")
        } else {
            let config = ConfigFile(from: settings)
            writeConfigFile(config)
            debugLog.log("Config", "Created initial config at \(configFileURL.path)")
        }
        observeSettingsChanges()
    }

    func save() {
        let config = ConfigFile(from: settings)
        writeConfigFile(config)
    }

    // MARK: - File I/O

    func loadConfigFile() -> ConfigFile? {
        let url = configFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let tomlString = try String(contentsOf: url, encoding: .utf8)
            return try TOMLDecoder().decode(ConfigFile.self, from: tomlString)
        } catch {
            debugLog.log("Config", "Failed to parse config: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    private func writeConfigFile(_ config: ConfigFile) {
        let dir = configDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let toml = config.toAnnotatedTOML()
            try toml.write(to: configFileURL, atomically: true, encoding: .utf8)
        } catch {
            debugLog.log("Config", "Failed to write config: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Observation

    private func observeSettingsChanges() {
        settings.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isSyncing else { return }
                self.save()
            }
            .store(in: &cancellables)
    }
}
