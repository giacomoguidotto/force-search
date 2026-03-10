import AppKit

/// A borderless, transparent overlay window that plays a single expanding-ring
/// animation at a given screen point and then removes itself.  Used to give
/// instant visual feedback the moment a force-click or hotkey is detected,
/// before the search panel has opened.
final class RippleOverlay {
    private var window: NSWindow?

    /// Shows a ripple centered on `point` (in NSScreen coordinates).
    /// The overlay respects the user's "show animations" preference.
    static func show(at point: NSPoint) {
        guard AppSettings.shared.showAnimations else { return }
        let overlay = RippleOverlay()
        overlay.present(at: point)
    }

    // MARK: - Private

    private func present(at point: NSPoint) {
        let maxRadius = AnimationConstants.Ripple.maxRadius
        let side = maxRadius * 2
        let origin = NSPoint(x: point.x - maxRadius, y: point.y - maxRadius)
        let frame = NSRect(origin: origin, size: NSSize(width: side, height: side))

        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(NSWindow.Level.floating.rawValue - 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let hostView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        hostView.wantsLayer = true
        win.contentView = hostView

        let ring = CAShapeLayer()
        let startRadius = AnimationConstants.Ripple.startRadius
        let center = CGPoint(x: maxRadius, y: maxRadius)
        ring.path = CGPath(
            ellipseIn: CGRect(
                x: center.x - startRadius,
                y: center.y - startRadius,
                width: startRadius * 2,
                height: startRadius * 2
            ),
            transform: nil
        )
        ring.fillColor = nil
        ring.strokeColor = ScryTheme.Colors.accent.cgColor
        ring.lineWidth = AnimationConstants.Ripple.lineWidth
        ring.opacity = 0
        hostView.layer?.addSublayer(ring)

        self.window = win
        win.orderFrontRegardless()

        // Expand path
        let endPath = CGPath(
            ellipseIn: CGRect(
                x: center.x - maxRadius,
                y: center.y - maxRadius,
                width: maxRadius * 2,
                height: maxRadius * 2
            ),
            transform: nil
        )

        let duration = AnimationConstants.Ripple.duration

        let pathAnim = CABasicAnimation(keyPath: "path")
        pathAnim.fromValue = ring.path
        pathAnim.toValue = endPath
        pathAnim.duration = duration
        pathAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [
            AnimationConstants.Ripple.peakOpacity,
            AnimationConstants.Ripple.peakOpacity,
            0.0,
        ]
        opacityAnim.keyTimes = [0.0, 0.25, 1.0]
        opacityAnim.duration = duration

        let lineAnim = CABasicAnimation(keyPath: "lineWidth")
        lineAnim.fromValue = AnimationConstants.Ripple.lineWidth
        lineAnim.toValue = AnimationConstants.Ripple.lineWidth * 0.4
        lineAnim.duration = duration
        lineAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [pathAnim, opacityAnim, lineAnim]
        group.duration = duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        }
        ring.add(group, forKey: "ripple")
        CATransaction.commit()
    }
}
