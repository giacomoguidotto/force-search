import AppKit

/// AppKit view for rendering native search results (e.g., Wikipedia summaries).
final class NativeResultView: NSScrollView {
    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func display(results: [SearchResult]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if results.isEmpty {
            let noResults = NSTextField(labelWithString: "No results found.")
            noResults.font = .systemFont(ofSize: 14)
            noResults.textColor = .secondaryLabelColor
            noResults.alignment = .center
            stackView.addArrangedSubview(noResults)
            return
        }

        for result in results {
            let card = createResultCard(result)
            stackView.addArrangedSubview(card)
        }
    }

    // MARK: - Private

    private func setup() {
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true

        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false
        contentView = clipView

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
        ])
    }

    private func createResultCard(_ result: SearchResult) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        container.alignment = .leading

        // Title
        let title = NSTextField(labelWithString: result.title)
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .labelColor
        title.lineBreakMode = .byWordWrapping
        title.maximumNumberOfLines = 2
        container.addArrangedSubview(title)

        // Thumbnail (if available)
        if let imageURL = result.imageURL {
            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 8
            imageView.layer?.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
                imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 200),
            ])

            // Load image async
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: imageURL),
                   let image = NSImage(data: data) {
                    await MainActor.run {
                        imageView.image = image
                    }
                }
            }

            container.addArrangedSubview(imageView)
        }

        // Snippet
        let snippet = NSTextField(wrappingLabelWithString: result.snippet)
        snippet.font = .systemFont(ofSize: 13)
        snippet.textColor = .secondaryLabelColor
        snippet.maximumNumberOfLines = 0
        container.addArrangedSubview(snippet)

        // URL link
        if let url = result.url {
            let linkButton = NSButton()
            linkButton.isBordered = false
            linkButton.title = "Read more on Wikipedia"
            linkButton.contentTintColor = .controlAccentColor
            linkButton.font = .systemFont(ofSize: 12)
            linkButton.target = self
            linkButton.action = #selector(openLink(_:))
            linkButton.toolTip = url.absoluteString
            container.addArrangedSubview(linkButton)
        }

        return container
    }

    @objc private func openLink(_ sender: NSButton) {
        if let urlString = sender.toolTip, let url = URL(string: urlString) {
            openInBrowser(url: url)
        }
    }

    private func openInBrowser(url: URL) {
        let settings = AppSettings.shared
        if let bundleID = settings.openLinksIn.bundleIdentifier {
            NSWorkspace.shared.open([url], withAppBundleIdentifier: bundleID, options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
