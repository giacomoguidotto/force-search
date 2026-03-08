import AppKit

/// Borderless, floating NSPanel with frosted glass appearance.
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: AppSettings.shared.panelWidth,
                                height: AppSettings.shared.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

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

        // Accent border (on the container, outside the clip)
        container.layer?.borderWidth = 1
        container.layer?.borderColor = ScryTheme.Colors.panelBorder.cgColor

        contentView = container

        alphaValue = CGFloat(settings.panelOpacity)
    }

    override func resignKey() {
        super.resignKey()
        // Let the controller know we lost focus
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
