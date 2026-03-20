import XCTest
import AppKit
@testable import Scry

final class PanelAppearanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let settings = AppSettings.shared
        settings.forceClick = true
        settings.hotkey = .modifierTap(.globe)
    }

    func testThemeAppearanceNames() {
        XCTAssertNil(Theme.system.appearanceName)
        XCTAssertEqual(Theme.light.appearanceName, .aqua)
        XCTAssertEqual(Theme.dark.appearanceName, .darkAqua)
    }

    func testThemeCodable() throws {
        for theme in Theme.allCases {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(Theme.self, from: data)
            XCTAssertEqual(theme, decoded)
        }
    }

    func testForceClickAndHotkeyDefaults() {
        let settings = AppSettings.shared
        XCTAssertTrue(settings.forceClick)
        XCTAssertEqual(settings.hotkey, .modifierTap(.globe))
    }

    func testLinkTargetBundleIdentifiers() {
        XCTAssertNil(LinkTarget.defaultBrowser.bundleIdentifier)
        XCTAssertNotNil(LinkTarget.safari.bundleIdentifier)
        XCTAssertNotNil(LinkTarget.chrome.bundleIdentifier)
    }
}
