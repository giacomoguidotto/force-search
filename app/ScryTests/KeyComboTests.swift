import XCTest
import Carbon
@testable import Scry

final class KeyComboTests: XCTestCase {

    func testDefaultKeyCombo() {
        let combo = KeyCombo.default
        XCTAssertEqual(combo.keyCode, UInt32(kVK_ANSI_G))
        XCTAssertTrue(combo.modifierFlags.contains(.command))
        XCTAssertTrue(combo.modifierFlags.contains(.shift))
    }

    func testDisplayString() {
        let combo = KeyCombo.default
        let display = combo.displayString
        XCTAssertTrue(display.contains("⇧"))
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("G"))
    }

    func testDisplayStringWithControl() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: [.control, .option])
        XCTAssertTrue(combo.displayString.contains("⌃"))
        XCTAssertTrue(combo.displayString.contains("⌥"))
        XCTAssertTrue(combo.displayString.contains("A"))
    }

    func testCarbonFlagsRoundTrip() {
        let original: NSEvent.ModifierFlags = [.command, .shift, .option]
        let carbon = original.carbonFlags
        let restored = NSEvent.ModifierFlags.fromCarbon(carbon)
        XCTAssertTrue(restored.contains(.command))
        XCTAssertTrue(restored.contains(.shift))
        XCTAssertTrue(restored.contains(.option))
        XCTAssertFalse(restored.contains(.control))
    }

    func testEquality() {
        let a = KeyCombo(keyCode: UInt32(kVK_ANSI_G), modifiers: [.command, .shift])
        let b = KeyCombo(keyCode: UInt32(kVK_ANSI_G), modifiers: [.command, .shift])
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = KeyCombo(keyCode: UInt32(kVK_ANSI_G), modifiers: [.command, .shift])
        let b = KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command, .shift])
        XCTAssertNotEqual(a, b)
    }

    func testCodable() throws {
        let original = KeyCombo(keyCode: UInt32(kVK_ANSI_F), modifiers: [.command, .control])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
