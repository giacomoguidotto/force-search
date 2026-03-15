import AppKit

/// A small transient tooltip that appears near a screen point, fades in,
/// lingers briefly, then fades out and removes itself. Used for non-blocking
/// feedback like permission warnings.
final class ToastOverlay {
    private var window: NSWindow?
    private static var activeToast: ToastOverlay?

    static func show(_ message: String, at point: NSPoint, color: NSColor = ScryTheme.Colors.error) {
        let toast = ToastOverlay()
        activeToast = toast
        toast.present(message, at: point, color: color)
    }

    // MARK: - Private

    private func present(_ message: String, at point: NSPoint, color: NSColor) {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textSize = (message as NSString).size(withAttributes: [.font: font])

        let hPad: CGFloat = 14
        let vPad: CGFloat = 8
        let dotSize: CGFloat = 6
        let width = textSize.width + hPad * 2 + dotSize + 4
        let height = textSize.height + vPad * 2

        let origin = NSPoint(x: point.x - width / 2, y: point.y + 24)
        let frame = NSRect(origin: origin, size: NSSize(width: width, height: height))

        let win = makeWindow(frame: frame)
        let hostView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        hostView.wantsLayer = true
        win.contentView = hostView

        guard let layer = hostView.layer else { return }
        let layout = ToastLayout(
            hPad: hPad, vPad: vPad, dotSize: dotSize, height: height,
            message: message, font: font, textSize: textSize, color: color
        )
        buildLayers(on: layer, layout: layout)

        layer.opacity = 0
        layer.transform = CATransform3DMakeTranslation(0, -6, 0)

        self.window = win
        win.orderFrontRegardless()

        animateEntrance(layer: layer)
        scheduleExit()
    }

    private func makeWindow(frame: NSRect) -> NSWindow {
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
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return win
    }

    private struct ToastLayout {
        let hPad: CGFloat
        let vPad: CGFloat
        let dotSize: CGFloat
        let height: CGFloat
        let message: String
        let font: NSFont
        let textSize: CGSize
        let color: NSColor
    }

    private func buildLayers(on layer: CALayer, layout: ToastLayout) {
        let color = layout.color
        let backdrop = CALayer()
        backdrop.frame = layer.bounds
        backdrop.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        backdrop.cornerRadius = layout.height / 2
        backdrop.borderWidth = 1
        backdrop.borderColor = color.withAlphaComponent(0.4).cgColor
        layer.addSublayer(backdrop)

        let dot = CAShapeLayer()
        dot.path = CGPath(
            ellipseIn: CGRect(
                x: layout.hPad,
                y: (layout.height - layout.dotSize) / 2,
                width: layout.dotSize,
                height: layout.dotSize
            ),
            transform: nil
        )
        dot.fillColor = color.cgColor
        layer.addSublayer(dot)

        let textLayer = CATextLayer()
        textLayer.string = layout.message
        textLayer.font = layout.font
        textLayer.fontSize = layout.font.pointSize
        textLayer.foregroundColor = NSColor(white: 0.88, alpha: 1.0).cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.frame = CGRect(
            x: layout.hPad + layout.dotSize + 6,
            y: layout.vPad - 1,
            width: layout.textSize.width + 4,
            height: layout.textSize.height
        )
        layer.addSublayer(textLayer)
    }

    private func animateEntrance(layer: CALayer) {
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.2
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let slideUp = CABasicAnimation(keyPath: "transform")
        slideUp.fromValue = layer.transform
        slideUp.toValue = CATransform3DIdentity
        slideUp.duration = 0.2
        slideUp.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [fadeIn, slideUp]
        group.duration = 0.2
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        layer.add(group, forKey: "enter")
        layer.opacity = 1
        layer.transform = CATransform3DIdentity
    }

    private func scheduleExit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, let layer = self.window?.contentView?.layer else { return }

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1.0
            fadeOut.toValue = 0.0
            fadeOut.duration = 0.3
            fadeOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                self.window?.orderOut(nil)
                self.window = nil
                ToastOverlay.activeToast = nil
            }
            layer.add(fadeOut, forKey: "exit")
            CATransaction.commit()
        }
    }
}
