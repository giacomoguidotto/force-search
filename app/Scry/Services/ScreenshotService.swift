import AppKit
import CoreGraphics

final class ScreenshotService {
    private let debugLog = DebugLogStore.shared

    /// Captures a screenshot of a square region around the given screen point.
    /// - Parameters:
    ///   - point: Cursor position in NSScreen coordinates (origin bottom-left).
    ///   - size: Width/height of the capture region in points.
    /// - Returns: The captured image, or nil if Screen Recording permission is missing.
    func captureRegion(around point: NSPoint, size: CGFloat) -> CGImage? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
                ?? NSScreen.main else {
            debugLog.log("Screenshot", "No screen found for point", level: .warning)
            return nil
        }

        // Convert NSScreen coords (bottom-left origin) to CG coords (top-left origin)
        let screenHeight = screen.frame.height + screen.frame.origin.y
        let cgY = screenHeight - point.y

        let half = size / 2
        let rect = CGRect(
            x: point.x - half,
            y: cgY - half,
            width: size,
            height: size
        )

        let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)

        if image == nil {
            debugLog.log("Screenshot", "Capture returned nil (Screen Recording permission missing?)", level: .warning)
        } else {
            debugLog.log("Screenshot", "Captured \(Int(size))x\(Int(size)) region", level: .debug)
        }

        return image
    }
}
