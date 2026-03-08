import AppKit

protocol ProviderTabBarDelegate: AnyObject {
    func tabBar(_ tabBar: ProviderTabBar, didSelectProviderAt index: Int)
}

/// Horizontal tab strip for switching between search providers.
final class ProviderTabBar: NSView {
    weak var delegate: ProviderTabBarDelegate?

    private var tabButtons: [NSButton] = []
    private var selectedIndex = 0
    private let stackView = NSStackView()
    private let selectionIndicator = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(providers: [SearchProvider], selectedIndex: Int = 0) {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        for (index, provider) in providers.enumerated() {
            let button = createTabButton(provider: provider, index: index)
            tabButtons.append(button)
            stackView.addArrangedSubview(button)
        }

        self.selectedIndex = selectedIndex
        updateSelection(animated: false)
    }

    func selectTab(at index: Int, animated: Bool = true) {
        guard index >= 0, index < tabButtons.count else { return }
        selectedIndex = index
        updateSelection(animated: animated)
    }

    // MARK: - Private

    private func setup() {
        wantsLayer = true

        stackView.orientation = .horizontal
        stackView.spacing = 2
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        selectionIndicator.wantsLayer = true
        selectionIndicator.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        selectionIndicator.layer?.cornerRadius = 6
        addSubview(selectionIndicator, positioned: .below, relativeTo: stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    private func createTabButton(provider: SearchProvider, index: Int) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.title = ""
        button.tag = index

        let attrTitle = NSMutableAttributedString()

        // Icon
        if let symbolImage = NSImage(systemSymbolName: provider.iconSymbolName, accessibilityDescription: provider.name) {
            let attachment = NSTextAttachment()
            attachment.image = symbolImage
            let iconString = NSAttributedString(attachment: attachment)
            attrTitle.append(iconString)
            attrTitle.append(NSAttributedString(string: " "))
        }

        // Name + shortcut hint
        let shortcutIndex = index + 1
        let label = "\(provider.name)"
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        attrTitle.append(NSAttributedString(string: label, attributes: labelAttrs))

        if shortcutIndex <= 9 {
            let shortcut = " ⌘\(shortcutIndex)"
            let shortcutAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]
            attrTitle.append(NSAttributedString(string: shortcut, attributes: shortcutAttrs))
        }

        button.attributedTitle = attrTitle
        button.target = self
        button.action = #selector(tabClicked(_:))

        return button
    }

    @objc private func tabClicked(_ sender: NSButton) {
        let index = sender.tag
        selectTab(at: index)
        delegate?.tabBar(self, didSelectProviderAt: index)
    }

    private func updateSelection(animated: Bool) {
        guard selectedIndex < tabButtons.count else { return }

        for (i, button) in tabButtons.enumerated() {
            button.contentTintColor = i == selectedIndex ? .controlAccentColor : .secondaryLabelColor
        }

        // Update selection indicator
        let selectedButton = tabButtons[selectedIndex]
        let targetFrame = selectedButton.frame.insetBy(dx: -2, dy: 0)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AnimationConstants.TabSwitch.contentFadeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                selectionIndicator.animator().frame = targetFrame
            }
        } else {
            selectionIndicator.frame = targetFrame
        }
    }

    override func layout() {
        super.layout()
        updateSelection(animated: false)
    }
}
