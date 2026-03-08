import XCTest
@testable import Scry

final class ConstantsTests: XCTestCase {

    func testPanelDefaultsAreSane() {
        XCTAssertGreaterThan(Constants.Panel.defaultWidth, 0)
        XCTAssertGreaterThan(Constants.Panel.defaultHeight, 0)
        XCTAssertGreaterThanOrEqual(Constants.Panel.defaultWidth, Constants.Panel.minWidth)
        XCTAssertLessThanOrEqual(Constants.Panel.defaultWidth, Constants.Panel.maxWidth)
        XCTAssertGreaterThanOrEqual(Constants.Panel.defaultHeight, Constants.Panel.minHeight)
        XCTAssertLessThanOrEqual(Constants.Panel.defaultHeight, Constants.Panel.maxHeight)
    }

    func testTimingValues() {
        XCTAssertGreaterThan(Constants.Timing.debounceCooldown, 0)
        XCTAssertGreaterThan(Constants.Timing.healthCheckInterval, 0)
        XCTAssertGreaterThan(Constants.Timing.maxQueryLength, 0)
    }

    func testAnimationConstants() {
        XCTAssertGreaterThan(AnimationConstants.PanelShow.opacityDuration, 0)
        XCTAssertGreaterThan(AnimationConstants.PanelDismiss.duration, 0)
        XCTAssertGreaterThan(AnimationConstants.TabSwitch.contentFadeDuration, 0)
        XCTAssertLessThan(AnimationConstants.PanelShow.initialScale, AnimationConstants.PanelShow.finalScale)
    }
}
