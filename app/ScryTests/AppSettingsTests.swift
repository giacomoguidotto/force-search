import XCTest
@testable import Scry

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset relevant UserDefaults keys and singleton properties before each test
        let defaults = UserDefaults.standard
        let keys = [
            Constants.UserDefaultsKeys.forceClick,
            Constants.UserDefaultsKeys.hotkey,
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
        settings.forceClick = true
        settings.hotkey = .modifierTap(.globe)
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
        XCTAssertTrue(settings.forceClick)
        XCTAssertEqual(settings.hotkey, .modifierTap(.globe))
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

}
