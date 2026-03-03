import AppKit

protocol SearchBarDelegate: AnyObject {
    func searchBarDidChangeQuery(_ query: String)
    func searchBarDidPressReturn()
    func searchBarDidPressClearButton()
}

/// Editable search bar at the top of the panel.
final class SearchBarView: NSView {
    weak var delegate: SearchBarDelegate?

    private let textField = NSTextField()
    private let iconView = NSImageView()
    private let clearButton = NSButton()

    var query: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func focus() {
        textField.selectText(nil)
    }

    // MARK: - Private

    private func setup() {
        wantsLayer = true

        // Search icon
        let icon = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        iconView.image = icon
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Text field
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 16, weight: .regular)
        textField.placeholderString = "Search..."
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        // Clear button (Cmd+Delete)
        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearButton.contentTintColor = .tertiaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clearTapped)
        clearButton.toolTip = "Clear (⌘⌫)"
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isHidden = true
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 18),
            clearButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @objc private func clearTapped() {
        textField.stringValue = ""
        clearButton.isHidden = true
        delegate?.searchBarDidPressClearButton()
    }

    private func updateClearButton() {
        clearButton.isHidden = textField.stringValue.isEmpty
    }
}

extension SearchBarView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateClearButton()
        delegate?.searchBarDidChangeQuery(textField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            delegate?.searchBarDidPressReturn()
            return true
        }
        return false
    }
}
