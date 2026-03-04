import AppKit
import Combine

final class SearchPanelController: NSObject {
    private var panel: SearchPanel?
    private let settings = AppSettings.shared
    private let registry = ProviderRegistry.shared
    private var cancellables = Set<AnyCancellable>()

    // UI components
    private var searchBar: SearchBarView!
    private var tabBar: ProviderTabBar!
    private var webViewController: SearchWebViewController!
    private var nativeResultView: NativeResultView!
    private var loadingBar: NSView!
    private var hintBar: NSView!
    private var contentContainer: NSView!
    private var placeholderLabel: NSTextField!

    // State
    private var currentQuery = ""
    private var currentProviders: [SearchProvider] = []
    private var selectedProviderIndex = 0
    private var clickOutsideMonitor: Any?

    /// Cached web view controllers per provider ID, to avoid re-fetching when switching tabs.
    private var webViewCache: [String: SearchWebViewController] = [:]
    /// The query that the cached pages were loaded with. Cache is invalidated on new queries.
    private var cachedQuery = ""

    func show(query: String, at point: NSPoint) {
        currentQuery = query
        currentProviders = registry.enabledProviders()

        guard !currentProviders.isEmpty else { return }

        // Determine initial provider
        let effectiveID = settings.effectiveProvider
        selectedProviderIndex = currentProviders.firstIndex(where: { $0.id == effectiveID }) ?? 0

        if panel == nil {
            createPanel()
        }

        // Configure UI
        searchBar.query = query
        tabBar.configure(providers: currentProviders, selectedIndex: selectedProviderIndex)

        // Position panel
        let panelFrame = calculateFrame(near: point)
        panel?.setFrame(panelFrame, display: false)

        // Show with animation
        showWithAnimation()

        // Load search
        performSearch()

        // Monitor for clicks outside
        startClickOutsideMonitor()

        // Listen for keyboard events
        startKeyMonitor()
    }

    func dismiss() {
        guard let panel = panel, panel.isVisible else { return }

        stopClickOutsideMonitor()
        stopKeyMonitor()

        if settings.showAnimations {
            dismissWithAnimation {
                self.cleanup()
            }
        } else {
            panel.orderOut(nil)
            cleanup()
        }
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panel = SearchPanel()
        self.panel = panel

        guard let contentView = panel.contentView else { return }

        // Search bar
        searchBar = SearchBarView()
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchBar)

        // Tab bar
        tabBar = ProviderTabBar()
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabBar)

        // Loading bar
        loadingBar = NSView()
        loadingBar.wantsLayer = true
        loadingBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        loadingBar.isHidden = true
        loadingBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingBar)

        // Content container
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentContainer)

        // Placeholder label (shown while content is loading)
        placeholderLabel = NSTextField(labelWithString: "Searching…")
        placeholderLabel.font = .systemFont(ofSize: 14, weight: .medium)
        placeholderLabel.textColor = .tertiaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
        ])

        // Web view
        webViewController = SearchWebViewController()
        webViewController.delegate = self
        webViewController.webView.translatesAutoresizingMaskIntoConstraints = false
        // Pre-warm WebKit process to avoid cold-start latency on first search
        webViewController.webView.loadHTMLString("", baseURL: nil)

        // Native result view
        nativeResultView = NativeResultView()
        nativeResultView.translatesAutoresizingMaskIntoConstraints = false

        // Hint bar
        hintBar = createHintBar()
        hintBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintBar)

        let hintHeight: CGFloat = settings.showShortcutHints ? Constants.Panel.hintBarHeight : 0

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: Constants.Panel.searchBarHeight),

            tabBar.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tabBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: Constants.Panel.tabBarHeight),

            loadingBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            loadingBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            loadingBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            loadingBar.heightAnchor.constraint(equalToConstant: AnimationConstants.Loading.barHeight),

            contentContainer.topAnchor.constraint(equalTo: loadingBar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: hintBar.topAnchor),

            hintBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hintBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hintBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hintBar.heightAnchor.constraint(equalToConstant: hintHeight),
        ])

        // Listen for panel events
        NotificationCenter.default.publisher(for: .searchPanelEscapePressed)
            .sink { [weak self] _ in self?.dismiss() }
            .store(in: &cancellables)
    }

    private func createHintBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.05).cgColor
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (key, label) in [("⎋", "Close"), ("⌘↩", "Open in Browser"), ("⌘C", "Copy URL")] {
            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            keyLabel.textColor = .tertiaryLabelColor
            let descLabel = NSTextField(labelWithString: label)
            descLabel.font = .systemFont(ofSize: 10)
            descLabel.textColor = .tertiaryLabelColor
            let pair = NSStackView(views: [keyLabel, descLabel])
            pair.spacing = 4
            stack.addArrangedSubview(pair)
        }
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        return bar
    }

    // MARK: - Content Display

    private func showPlaceholder(_ text: String) {
        placeholderLabel.stringValue = text
        placeholderLabel.isHidden = false
    }

    private func hidePlaceholder() {
        placeholderLabel.isHidden = true
    }

    private func showWebContent(for provider: SearchProvider) {
        nativeResultView.removeFromSuperview()

        // Invalidate cache if query changed
        if cachedQuery != currentQuery {
            clearWebViewCache()
            cachedQuery = currentQuery
        }

        // Reuse cached web view controller for this provider, or create a new one
        let controller: SearchWebViewController
        if let cached = webViewCache[provider.id] {
            controller = cached
        } else {
            controller = SearchWebViewController()
            controller.delegate = self
            webViewCache[provider.id] = controller
        }

        // Remove the previous web view from display
        webViewController.webView.removeFromSuperview()
        webViewController = controller

        // Show loading placeholder until the page finishes (only for uncached loads)
        showPlaceholder("Searching…")

        let wv = controller.webView
        wv.translatesAutoresizingMaskIntoConstraints = false
        if wv.superview !== contentContainer {
            wv.removeFromSuperview()
            contentContainer.addSubview(wv)
            NSLayoutConstraint.activate([
                wv.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                wv.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                wv.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                wv.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            ])
        }

        // If this page was already loaded for the same query, skip the network request
        if controller.currentURL != nil && cachedQuery == currentQuery {
            hidePlaceholder()
            loadingBar.isHidden = true
            stopLoadingAnimation()
        } else {
            controller.search(query: currentQuery, provider: provider)
        }
    }

    private func clearWebViewCache() {
        for (_, controller) in webViewCache {
            controller.stopLoading()
        }
        webViewCache.removeAll()
    }

    private func showNativeContent(for provider: SearchProvider) {
        webViewController.webView.removeFromSuperview()
        webViewController.stopLoading()

        if nativeResultView.superview !== contentContainer {
            nativeResultView.removeFromSuperview()
            contentContainer.addSubview(nativeResultView)
            NSLayoutConstraint.activate([
                nativeResultView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                nativeResultView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                nativeResultView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                nativeResultView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            ])
        }

        hidePlaceholder()
        loadingBar.isHidden = false
        startLoadingAnimation()

        Task {
            do {
                let results = try await provider.search(query: currentQuery)
                await MainActor.run {
                    nativeResultView.display(results: results)
                    loadingBar.isHidden = true
                    stopLoadingAnimation()
                }
            } catch {
                await MainActor.run {
                    nativeResultView.display(
                        results: [],
                        errorMessage: "Search failed — please try again."
                    )
                    loadingBar.isHidden = true
                    stopLoadingAnimation()
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch() {
        guard selectedProviderIndex < currentProviders.count else { return }
        let provider = currentProviders[selectedProviderIndex]

        settings.lastUsedProvider = provider.id

        if provider.supportsNativeRendering {
            showNativeContent(for: provider)
        } else {
            showWebContent(for: provider)
        }
    }

    // MARK: - Positioning

    private func calculateFrame(near point: NSPoint) -> NSRect {
        let (w, h, margin) = (settings.panelWidth, settings.panelHeight, Constants.Panel.edgeMargin)
        let screenFrame = NSScreen.visibleFrameContaining(point: point)
        var origin = NSPoint(x: point.x - w / 2, y: point.y - h - 20)
        if origin.y < screenFrame.minY + margin { origin.y = point.y + 20 }
        return NSScreen.clampedFrame(
            NSRect(origin: origin, size: NSSize(width: w, height: h)), to: screenFrame, margin: margin
        )
    }

    // MARK: - Animations

    private func showWithAnimation() {
        guard let panel = panel else { return }

        if settings.showAnimations {
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)

            // Scale from 0.97 → 1.0
            if let contentView = panel.contentView {
                contentView.wantsLayer = true
                let scale = AnimationConstants.PanelShow.initialScale
                contentView.layer?.setAffineTransform(
                    CGAffineTransform(scaleX: scale, y: scale)
                )
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = AnimationConstants.PanelShow.duration
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
                panel.animator().alphaValue = CGFloat(settings.panelOpacity)
                panel.contentView?.animator().layer?.setAffineTransform(.identity)
            }
        } else {
            panel.alphaValue = CGFloat(settings.panelOpacity)
            panel.makeKeyAndOrderFront(nil)
        }

        searchBar.focus()
    }

    private func dismissWithAnimation(completion: @escaping () -> Void) {
        guard let panel = panel else {
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AnimationConstants.PanelDismiss.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            completion()
        })
    }

    private func startLoadingAnimation() {
        loadingBar.wantsLayer = true
        let anim = CABasicAnimation(keyPath: "position.x")
        anim.fromValue = -100
        anim.toValue = settings.panelWidth + 100
        anim.duration = 1.0
        anim.repeatCount = .infinity
        loadingBar.layer?.add(anim, forKey: "loading")
    }

    private func stopLoadingAnimation() {
        loadingBar.layer?.removeAnimation(forKey: "loading")
    }

    // MARK: - Click Outside / Key Monitor

    private var keyMonitor: Any?

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
            guard let self = self, let panel = panel else { return }
            let screenPoint = event.locationInWindow
            // If click is outside the panel, dismiss
            if !panel.frame.contains(screenPoint) {
                self.dismiss()
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape → dismiss
        if event.keyCode == 53 { // kVK_Escape
            dismiss()
            return true
        }

        // Cmd+1..9 → switch tabs
        if flags.contains(.command), let num = Int(event.charactersIgnoringModifiers ?? ""), num >= 1, num <= 9 {
            let index = num - 1
            if index < currentProviders.count {
                selectedProviderIndex = index
                tabBar.selectTab(at: index)
                performSearch()
            }
            return true
        }

        // Cmd+Return → open in browser
        if flags.contains(.command) && event.keyCode == 36 { // kVK_Return
            openInBrowser()
            return true
        }

        // Cmd+C → copy URL
        if flags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            copyURL()
            return true
        }

        // Cmd+Delete → clear search
        if flags.contains(.command) && event.keyCode == 51 { // kVK_Delete
            searchBar.query = ""
            return true
        }

        return false
    }

    // MARK: - Actions

    private func openInBrowser() {
        guard let url = currentBrowserURL() else { return }
        let target = settings.openLinksIn
        if let bundleID = target.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
        dismiss()
    }

    private func copyURL() {
        guard let url = currentBrowserURL() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    private func currentBrowserURL() -> URL? {
        if let url = webViewController.currentURL {
            return url
        }
        // For native providers, construct a search URL
        guard selectedProviderIndex < currentProviders.count else { return nil }
        return currentProviders[selectedProviderIndex].searchURL(for: currentQuery)
    }

    private func cleanup() {
        webViewController.stopLoading()
        clearWebViewCache()
    }
}

// MARK: - SearchBarDelegate

extension SearchPanelController: SearchBarDelegate {
    func searchBarDidChangeQuery(_ query: String) {
        // Debounce handled by the user pressing Return
    }

    func searchBarDidPressReturn() {
        currentQuery = String(searchBar.query.prefix(settings.maxQueryLength))
        performSearch()
    }

    func searchBarDidPressClearButton() {
        currentQuery = ""
    }
}

// MARK: - ProviderTabBarDelegate

extension SearchPanelController: ProviderTabBarDelegate {
    func tabBar(_ tabBar: ProviderTabBar, didSelectProviderAt index: Int) {
        guard index != selectedProviderIndex else { return }
        selectedProviderIndex = index

        // Show loading indicator during tab switch
        loadingBar.isHidden = false
        startLoadingAnimation()

        // Cross-fade animation
        if settings.showAnimations {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AnimationConstants.TabSwitch.duration
                contentContainer.animator().alphaValue = 0
            } completionHandler: {
                self.performSearch()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = AnimationConstants.TabSwitch.duration
                    self.contentContainer.animator().alphaValue = 1
                }
            }
        } else {
            performSearch()
        }
    }
}

// MARK: - SearchWebViewDelegate

extension SearchPanelController: SearchWebViewDelegate {
    func webViewDidStartLoading() {
        loadingBar.isHidden = false
        startLoadingAnimation()
    }

    func webViewDidFinishLoading() {
        hidePlaceholder()
        loadingBar.isHidden = true
        stopLoadingAnimation()
    }

    func webViewDidFailLoading(error: Error) {
        loadingBar.isHidden = true
        stopLoadingAnimation()
        showPlaceholder("Search failed — please try again.")
    }

    func webViewRequestedExternalNavigation(url: URL) {
        let target = settings.openLinksIn
        if let bundleID = target.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }

        if settings.dismissOnLinkClick {
            dismiss()
        }
    }
}
