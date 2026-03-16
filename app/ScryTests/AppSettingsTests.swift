import XCTest
@testable import Scry

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset relevant UserDefaults keys and singleton properties before each test
        let defaults = UserDefaults.standard
        let keys = [
            Constants.UserDefaultsKeys.forceClickEnabled,
            Constants.UserDefaultsKeys.doubleTapEnabled,
            Constants.UserDefaultsKeys.doubleTapModifier,
            Constants.UserDefaultsKeys.hotKeyEnabled,
            Constants.UserDefaultsKeys.pressureSensitivity,
            Constants.UserDefaultsKeys.panelWidth,
            Constants.UserDefaultsKeys.panelHeight,
            Constants.UserDefaultsKeys.showAnimations,
            Constants.UserDefaultsKeys.theme,
            Constants.UserDefaultsKeys.defaultProvider,
            Constants.UserDefaultsKeys.enabledProviders,
            Constants.UserDefaultsKeys.providerOrder,
        ]
        for key in keys { defaults.removeObject(forKey: key) }

        // Reset singleton properties to code defaults (CI may have overridden them)
        let settings = AppSettings.shared
        settings.forceClickEnabled = true
        settings.doubleTapEnabled = true
        settings.doubleTapModifier = .globe
        settings.hotKeyEnabled = false
        settings.pressureSensitivity = Constants.Defaults.pressureSensitivity
        settings.panelWidth = Constants.Panel.defaultWidth
        settings.panelHeight = Constants.Panel.defaultHeight
        settings.showAnimations = true
        settings.theme = .system
        settings.defaultProvider = "google"
        settings.enabledProviders = Constants.Defaults.enabledProviders
        settings.providerOrder = Constants.Defaults.enabledProviders
    }

    func testDefaultValues() {
        let settings = AppSettings.shared
        XCTAssertTrue(settings.forceClickEnabled)
        XCTAssertTrue(settings.doubleTapEnabled)
        XCTAssertEqual(settings.doubleTapModifier, .globe)
        XCTAssertFalse(settings.hotKeyEnabled)
        XCTAssertEqual(settings.pressureSensitivity, Constants.Defaults.pressureSensitivity)
        XCTAssertEqual(settings.panelWidth, Constants.Panel.defaultWidth)
        XCTAssertEqual(settings.panelHeight, Constants.Panel.defaultHeight)
        XCTAssertTrue(settings.showAnimations)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.defaultProvider, "google")
    }

    func testEnabledProvidersDefault() {
        let settings = AppSettings.shared
        XCTAssertEqual(settings.enabledProviders, ["google", "duckduckgo", "wikipedia"])
        XCTAssertEqual(settings.providerOrder, ["google", "duckduckgo", "wikipedia"])
    }

    func testEffectiveProvider_defaultsToGoogle() {
        let settings = AppSettings.shared
        settings.rememberLastProvider = false
        XCTAssertEqual(settings.effectiveProvider, "google")
    }

    func testEffectiveProvider_remembersLastUsed() {
        let settings = AppSettings.shared
        settings.rememberLastProvider = true
        settings.lastUsedProvider = "wikipedia"
        XCTAssertEqual(settings.effectiveProvider, "wikipedia")
    }

    func testExportImportRoundTrip() {
        let settings = AppSettings.shared
        settings.panelWidth = 600
        settings.theme = .dark
        settings.showAnimations = false

        guard let data = settings.exportSettings() else {
            XCTFail("Export returned nil")
            return
        }

        // Reset
        settings.panelWidth = Constants.Panel.defaultWidth
        settings.theme = .system
        settings.showAnimations = true

        // Import
        let success = settings.importSettings(from: data)
        XCTAssertTrue(success)
        XCTAssertEqual(settings.panelWidth, 600)
        XCTAssertEqual(settings.theme, .dark)
        XCTAssertFalse(settings.showAnimations)
    }

    func testImportInvalidData() {
        let settings = AppSettings.shared
        let garbage = Data("not json".utf8)
        XCTAssertFalse(settings.importSettings(from: garbage))
    }
}
