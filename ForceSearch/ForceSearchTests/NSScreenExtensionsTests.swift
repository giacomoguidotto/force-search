import XCTest
import AppKit
@testable import ForceSearch

final class NSScreenExtensionsTests: XCTestCase {

    func testClampedFrameKeepsFrameInside() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelFrame = NSRect(x: -50, y: -50, width: 520, height: 580)
        let clamped = NSScreen.clampedFrame(panelFrame, to: screenFrame, margin: 12)

        XCTAssertGreaterThanOrEqual(clamped.minX, 12)
        XCTAssertGreaterThanOrEqual(clamped.minY, 12)
        XCTAssertLessThanOrEqual(clamped.maxX, 1920 - 12)
        XCTAssertLessThanOrEqual(clamped.maxY, 1080 - 12)
    }

    func testClampedFrameDoesNotMoveAlreadyValidFrame() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelFrame = NSRect(x: 500, y: 300, width: 520, height: 580)
        let clamped = NSScreen.clampedFrame(panelFrame, to: screenFrame, margin: 12)

        XCTAssertEqual(clamped.origin.x, 500)
        XCTAssertEqual(clamped.origin.y, 300)
    }

    func testClampedFrameRightEdge() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelFrame = NSRect(x: 1800, y: 300, width: 520, height: 580)
        let clamped = NSScreen.clampedFrame(panelFrame, to: screenFrame, margin: 12)

        XCTAssertLessThanOrEqual(clamped.maxX, 1920 - 12)
    }

    func testConvertFromTopLeft() {
        // This test depends on screen geometry, so we just test the math:
        // If main screen is 1080 tall, y=100 top-left → y=980 bottom-left
        if let mainScreen = NSScreen.screens.first {
            let height = mainScreen.frame.height
            let point = NSScreen.convertFromTopLeft(NSPoint(x: 100, y: 100))
            XCTAssertEqual(point.x, 100)
            XCTAssertEqual(point.y, height - 100)
        }
    }
}
