import XCTest
import AppKit
@testable import Scry

final class PanelAppearanceTests: XCTestCase {

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

    func testForceClickAndHotKeyDefaults() {
        let settings = AppSettings.shared
        XCTAssertTrue(settings.forceClickEnabled)
        XCTAssertTrue(settings.doubleTapEnabled)
        XCTAssertEqual(settings.doubleTapModifier, .globe)
        XCTAssertFalse(settings.hotKeyEnabled)
    }

    func testLinkTargetBundleIdentifiers() {
        XCTAssertNil(LinkTarget.defaultBrowser.bundleIdentifier)
        XCTAssertNotNil(LinkTarget.safari.bundleIdentifier)
        XCTAssertNotNil(LinkTarget.chrome.bundleIdentifier)
    }

    func testMenuBarIconStyleSymbolNames() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertFalse(style.symbolName.isEmpty)
        }
    }
}
