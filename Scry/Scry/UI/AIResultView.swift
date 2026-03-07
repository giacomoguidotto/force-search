import AppKit
import Combine

/// AppKit view that displays streaming LLM response text.
final class AIResultView: NSScrollView {
    private let textView = NSTextView()
    private var cancellables = Set<AnyCancellable>()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Binds to a streaming response, updating text as it arrives.
    func observe(response: LLMStreamingResponse) {
        cancellables.removeAll()
        textView.string = ""

        response.$text
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.textView.string = text
                self?.scrollToEnd()
            }
            .store(in: &cancellables)

        response.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
    }

    func clear() {
        cancellables.removeAll()
        textView.string = ""
    }

    // MARK: - Private

    private func setup() {
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        documentView = textView
    }

    private func scrollToEnd() {
        let length = textView.string.count
        textView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }

    private func showError(_ message: String) {
        let attributed = NSAttributedString(
            string: message,
            attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: 13),
            ]
        )
        textView.textStorage?.setAttributedString(attributed)
    }
}
