import AppKit

/// Borderless, floating NSPanel with frosted glass appearance and edge-drag resizing.
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Thickness of the invisible resize hit-test border around the panel edges.
    private static let resizeEdge: CGFloat = 6

    /// Which edges are being dragged — empty when idle.
    private var resizeEdges: ResizeEdge = []

    /// Window frame at the start of the drag.
    private var dragStartFrame: NSRect = .zero

    /// Mouse screen location at the start of the drag.
    private var dragStartMouse: NSPoint = .zero

    private struct ResizeEdge: OptionSet {
        let rawValue: Int
        static let left   = ResizeEdge(rawValue: 1 << 0)
        static let right  = ResizeEdge(rawValue: 1 << 1)
        static let top    = ResizeEdge(rawValue: 1 << 2)
        static let bottom = ResizeEdge(rawValue: 1 << 3)
    }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: AppSettings.shared.panelWidth,
                                height: AppSettings.shared.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )

        minSize = NSSize(width: Constants.Panel.minWidth, height: Constants.Panel.minHeight)
        maxSize = NSSize(width: Constants.Panel.maxWidth, height: Constants.Panel.maxHeight)
        configure()
    }

    private func configure() {
        let settings = AppSettings.shared

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Always dark
        appearance = ScryTheme.darkAppearance

        let radius = Constants.Panel.defaultCornerRadius

        // Container that clips content to the rounded shape
        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = radius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        // Frosted glass background
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.material = .windowBackground
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.autoresizingMask = [.width, .height]
        container.addSubview(visualEffect)

        // Accent border
        container.layer?.borderWidth = 1
        container.layer?.borderColor = ScryTheme.Colors.panelBorder.cgColor

        contentView = container

        alphaValue = CGFloat(settings.panelOpacity)
    }

    // MARK: - Edge-drag resizing

    override func mouseDown(with event: NSEvent) {
        let local = event.locationInWindow
        resizeEdges = hitTestEdges(local)

        if resizeEdges.isEmpty {
            super.mouseDown(with: event)
            return
        }

        dragStartFrame = frame
        dragStartMouse = convertPoint(toScreen: local)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !resizeEdges.isEmpty else {
            super.mouseDragged(with: event)
            return
        }

        let current = convertPoint(toScreen: event.locationInWindow)
        let deltaX = current.x - dragStartMouse.x
        let deltaY = current.y - dragStartMouse.y

        var newFrame = dragStartFrame

        if resizeEdges.contains(.right) {
            newFrame.size.width = dragStartFrame.width + deltaX
        }
        if resizeEdges.contains(.left) {
            newFrame.size.width = dragStartFrame.width - deltaX
            newFrame.origin.x = dragStartFrame.origin.x + deltaX
        }
        if resizeEdges.contains(.top) {
            newFrame.size.height = dragStartFrame.height + deltaY
        }
        if resizeEdges.contains(.bottom) {
            newFrame.size.height = dragStartFrame.height - deltaY
            newFrame.origin.y = dragStartFrame.origin.y + deltaY
        }

        // Clamp to min/max
        newFrame.size.width = max(minSize.width, min(maxSize.width, newFrame.size.width))
        newFrame.size.height = max(minSize.height, min(maxSize.height, newFrame.size.height))

        // If clamped, don't shift origin for left/bottom edges
        if resizeEdges.contains(.left) {
            newFrame.origin.x = dragStartFrame.maxX - newFrame.size.width
        }
        if resizeEdges.contains(.bottom) {
            newFrame.origin.y = dragStartFrame.maxY - newFrame.size.height
        }

        setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if !resizeEdges.isEmpty {
            resizeEdges = []
            // Persist the new size
            let settings = AppSettings.shared
            settings.panelWidth = frame.width
            settings.panelHeight = frame.height
        } else {
            super.mouseUp(with: event)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        // Prevent default cursor updates inside the resize edge zone
    }

    override func mouseMoved(with event: NSEvent) {
        let edges = hitTestEdges(event.locationInWindow)
        updateCursor(for: edges)
        if edges.isEmpty {
            super.mouseMoved(with: event)
        }
    }

    // MARK: - Cursor

    private func updateCursor(for edges: ResizeEdge) {
        if edges.contains(.left) || edges.contains(.right) {
            NSCursor.resizeLeftRight.set()
        } else if edges.contains(.top) || edges.contains(.bottom) {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Hit testing

    private func hitTestEdges(_ point: NSPoint) -> ResizeEdge {
        let e = Self.resizeEdge
        let bounds = contentView?.bounds ?? self.frame
        var edges: ResizeEdge = []

        if point.x < e { edges.insert(.left) }
        if point.x > bounds.width - e { edges.insert(.right) }
        if point.y < e { edges.insert(.bottom) }
        if point.y > bounds.height - e { edges.insert(.top) }

        return edges
    }

    // MARK: - Panel events

    override func resignKey() {
        super.resignKey()
        NotificationCenter.default.post(name: .searchPanelDidResignKey, object: self)
    }

    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: .searchPanelEscapePressed, object: self)
    }
}

extension Notification.Name {
    static let searchPanelDidResignKey = Notification.Name("searchPanelDidResignKey")
    static let searchPanelEscapePressed = Notification.Name("searchPanelEscapePressed")
}
