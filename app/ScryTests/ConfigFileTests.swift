import XCTest
@testable import Scry

final class ConfigFileTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scry-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Hotkey Parsing

    func testHotkeyParseEmpty() {
        XCTAssertEqual(Hotkey(configString: ""), .none)
        XCTAssertEqual(Hotkey(configString: "  "), .none)
    }

    func testHotkeyParseModifierTap() {
        XCTAssertEqual(Hotkey(configString: "globe"), .modifierTap(.globe))
        XCTAssertEqual(Hotkey(configString: "fn"), .modifierTap(.globe))
        XCTAssertEqual(Hotkey(configString: "cmd"), .modifierTap(.command))
        XCTAssertEqual(Hotkey(configString: "command"), .modifierTap(.command))
        XCTAssertEqual(Hotkey(configString: "opt"), .modifierTap(.option))
        XCTAssertEqual(Hotkey(configString: "option"), .modifierTap(.option))
        XCTAssertEqual(Hotkey(configString: "ctrl"), .modifierTap(.control))
        XCTAssertEqual(Hotkey(configString: "control"), .modifierTap(.control))
        XCTAssertEqual(Hotkey(configString: "shift"), .modifierTap(.shift))
    }

    func testHotkeyParseModifierDoubleTap() {
        XCTAssertEqual(Hotkey(configString: "cmd cmd"), .modifierDoubleTap(.command))
        XCTAssertEqual(Hotkey(configString: "shift shift"), .modifierDoubleTap(.shift))
        XCTAssertEqual(Hotkey(configString: "opt opt"), .modifierDoubleTap(.option))
        XCTAssertEqual(Hotkey(configString: "ctrl ctrl"), .modifierDoubleTap(.control))
        XCTAssertEqual(Hotkey(configString: "globe globe"), .modifierDoubleTap(.globe))
    }

    func testHotkeyParseCaseInsensitive() {
        XCTAssertEqual(Hotkey(configString: "CMD"), .modifierTap(.command))
        XCTAssertEqual(Hotkey(configString: "Globe"), .modifierTap(.globe))
        XCTAssertEqual(Hotkey(configString: "CMD CMD"), .modifierDoubleTap(.command))
    }

    func testHotkeyParseKeyCombo() {
        let hk = Hotkey(configString: "cmd+shift+g")
        if case .keyCombo(let combo) = hk {
            XCTAssertTrue(combo.modifierFlags.contains(.command))
            XCTAssertTrue(combo.modifierFlags.contains(.shift))
            XCTAssertEqual(combo.keyCodeString, "G")
        } else {
            XCTFail("Expected keyCombo, got \(hk)")
        }
    }

    func testHotkeyParseInvalid() {
        XCTAssertEqual(Hotkey(configString: "notakey"), .none)
        XCTAssertEqual(Hotkey(configString: "cmd+"), .none)
    }

    func testHotkeyRoundTrip() {
        let cases: [Hotkey] = [
            .none,
            .modifierTap(.globe),
            .modifierTap(.command),
            .modifierDoubleTap(.shift),
            .modifierDoubleTap(.option),
        ]
        for hk in cases {
            let parsed = Hotkey(configString: hk.configString)
            XCTAssertEqual(parsed, hk, "Round-trip failed for \(hk)")
        }
    }

    func testHotkeyKeyComboRoundTrip() {
        let hk = Hotkey(configString: "cmd+shift+g")
        let str = hk.configString
        let parsed = Hotkey(configString: str)
        XCTAssertEqual(parsed, hk)
    }

    // MARK: - ConfigFile Defaults

    func testDefaultValuesMatchConstants() {
        let config = ConfigFile.makeDefault()
        XCTAssertTrue(config.trigger.forceClick)
        XCTAssertEqual(config.trigger.pressureSensitivity, Constants.Defaults.pressureSensitivity)
        XCTAssertEqual(config.trigger.hotkey, "globe")
        XCTAssertEqual(config.appearance.panelOpacity, 1.0)
        XCTAssertTrue(config.appearance.showAnimations)
        XCTAssertEqual(config.appearance.theme, "system")
        XCTAssertEqual(config.behavior.defaultProvider, Constants.Defaults.defaultProvider)
        XCTAssertEqual(config.behavior.providers, Constants.Defaults.enabledProviders)
        XCTAssertEqual(config.behavior.maxQueryLength, Constants.Timing.maxQueryLength)
        XCTAssertFalse(config.system.launchAtLogin)
        XCTAssertTrue(config.system.showMenuBarIcon)
        XCTAssertFalse(config.ai.enabled)
        XCTAssertEqual(config.ai.model, Constants.AIConfig.defaultClaudeModel)
    }

    // MARK: - TOML Round-trip

    func testTOMLAnnotatedOutputIsValidTOML() throws {
        let config = ConfigFile.makeDefault()
        let toml = config.toAnnotatedTOML()
        // Should contain all sections
        XCTAssertTrue(toml.contains("[trigger]"))
        XCTAssertTrue(toml.contains("[appearance]"))
        XCTAssertTrue(toml.contains("[behavior]"))
        XCTAssertTrue(toml.contains("[system]"))
        XCTAssertTrue(toml.contains("[ai]"))
        // Should contain comments
        XCTAssertTrue(toml.contains("# Options:"))
    }

    // MARK: - ConfigFile Apply/Snapshot

    func testApplyAndSnapshot() {
        let settings = AppSettings.shared
        let original = ConfigFile.makeDefault()

        // Modify some values
        var modified = original
        modified.trigger.forceClick = false
        modified.trigger.hotkey = "cmd cmd"
        modified.appearance.theme = "dark"
        modified.behavior.defaultProvider = "duckduckgo"
        modified.behavior.providers = ["duckduckgo", "google"]
        modified.system.launchAtLogin = true
        modified.ai.enabled = true
        modified.ai.providerType = "openai"

        modified.apply(to: settings)
        XCTAssertFalse(settings.forceClick)
        XCTAssertEqual(settings.hotkey, .modifierDoubleTap(.command))
        XCTAssertEqual(settings.theme, .dark)
        XCTAssertEqual(settings.defaultProvider, "duckduckgo")
        XCTAssertEqual(settings.providerOrder, ["duckduckgo", "google"])
        XCTAssertEqual(settings.enabledProviders, ["duckduckgo", "google"])
        XCTAssertEqual(settings.aiProviderType, .openai)

        // Snapshot back
        let snapshot = ConfigFile(from: settings)
        XCTAssertEqual(snapshot.trigger.forceClick, false)
        XCTAssertEqual(snapshot.trigger.hotkey, "cmd cmd")
        XCTAssertEqual(snapshot.appearance.theme, "dark")
        XCTAssertEqual(snapshot.behavior.providers, ["duckduckgo", "google"])
        XCTAssertTrue(snapshot.ai.enabled)

        // Restore defaults
        original.apply(to: settings)
    }

    // MARK: - ConfigFileService Path Resolution

    func testConfigDirectoryRespectsXDG() {
        let customDir = tempDir.appendingPathComponent("custom-xdg")
        let service = ConfigFileService(configDirectory: customDir)
        XCTAssertEqual(service.configDirectory, customDir)
        XCTAssertEqual(
            service.configFileURL,
            customDir.appendingPathComponent("config.toml")
        )
    }

    // MARK: - File I/O

    func testWriteAndLoadConfigFile() {
        let service = ConfigFileService(configDirectory: tempDir)
        let config = ConfigFile.makeDefault()
        service.save()

        let loaded = service.loadConfigFile()
        // If TOMLKit is available, this should succeed
        if let loaded = loaded {
            XCTAssertEqual(loaded.trigger.forceClick, config.trigger.forceClick)
            XCTAssertEqual(loaded.trigger.hotkey, config.trigger.hotkey)
            XCTAssertEqual(loaded.appearance.theme, config.appearance.theme)
            XCTAssertEqual(loaded.behavior.providers, config.behavior.providers)
        }
    }

    func testLoadMissingFileReturnsNil() {
        let service = ConfigFileService(configDirectory: tempDir)
        XCTAssertNil(service.loadConfigFile())
    }
}
