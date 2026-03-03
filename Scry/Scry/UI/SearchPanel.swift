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

        // Apply theme
        if let appearanceName = settings.theme.appearanceName {
            appearance = NSAppearance(named: appearanceName)
        }

        // Create visual effect view as content
        let visualEffect = NSVisualEffectView(frame: contentRect(forFrameRect: frame))
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = settings.cornerRadius
        visualEffect.layer?.masksToBounds = true

        contentView = visualEffect

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
