import AppKit

extension NSScreen {
    /// Returns the screen containing the given point (in screen coordinates).
    static func screenContaining(point: NSPoint) -> NSScreen? {
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// Returns the visible frame (excluding menu bar and dock) of the screen containing the point.
    static func visibleFrameContaining(point: NSPoint) -> NSRect {
        return screenContaining(point: point)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    }

    /// Clamps a panel frame to stay within the visible screen area with the given margin.
    static func clampedFrame(_ frame: NSRect, to screenFrame: NSRect, margin: CGFloat = Constants.Panel.edgeMargin) -> NSRect {
        var clamped = frame
        let insetScreen = screenFrame.insetBy(dx: margin, dy: margin)

        clamped.origin.x = max(insetScreen.minX, min(clamped.origin.x, insetScreen.maxX - clamped.width))
        clamped.origin.y = max(insetScreen.minY, min(clamped.origin.y, insetScreen.maxY - clamped.height))

        return clamped
    }

    /// Converts a point from global screen coordinates (top-left origin) to AppKit coordinates (bottom-left origin).
    static func convertFromTopLeft(_ point: NSPoint) -> NSPoint {
        guard let mainScreen = NSScreen.screens.first else { return point }
        return NSPoint(x: point.x, y: mainScreen.frame.height - point.y)
    }
}
