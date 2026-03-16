import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
  static private(set) weak var shared: AppDelegate?

  private let settings = AppSettings.shared
  private let permissions = PermissionsService.shared
  private var onboardingController = OnboardingWindowController()
  private var preferencesController: PreferencesWindowController?
  private var eventTapService: EventTapService?
  private var textExtractorService: TextExtractorService?
  private var hotKeyService: HotKeyService?
  private var doubleTapService: DoubleTapService?
  private var searchPanelController: SearchPanelController?
  private var cancellables = Set<AnyCancellable>()
  private var lastPermissionToast: Date = .distantPast
  private let permissionToastCooldown: TimeInterval = 60

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self

    // Request accessibility once on boot (shows system prompt if not granted)
    permissions.requestAccessibility()

    // Show onboarding if first run
    if !settings.hasCompletedOnboarding {
      onboardingController.show()
    }

    // Start Sparkle updater
    _ = UpdaterService.shared

    // Initialize services
    setupServices()

    // Watch for settings changes
    observeSettings()
  }

  func applicationWillTerminate(_ notification: Notification) {
    eventTapService?.stop()
    hotKeyService?.unregister()
    doubleTapService?.stop()
    searchPanelController?.dismiss()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // MARK: - Public

  func showPreferences() {
    if preferencesController == nil {
      preferencesController = PreferencesWindowController()
    }
    preferencesController?.show()
  }

  func showOnboarding() {
    onboardingController.show()
  }

  func performSearch(at point: NSPoint?) {
    let debugLog = DebugLogStore.shared
    debugLog.log("Search", "performSearch called", level: .debug)

    let position = point ?? NSEvent.mouseLocation

    // Check accessibility permission
    permissions.checkAll()
    if !permissions.accessibilityGranted {
      debugLog.log("Search", "Accessibility not granted", level: .warning)
      RippleOverlay.show(at: position, color: ScryTheme.Colors.error)
      let now = Date()
      if now.timeIntervalSince(lastPermissionToast) >= permissionToastCooldown {
        lastPermissionToast = now
        ToastOverlay.show("Accessibility permission required", at: position)
      }
      return
    }

    // Instant visual feedback before async work begins
    RippleOverlay.show(at: position)

    Task { @MainActor in
      let query = await textExtractorService?.extractText(at: position)

      let effectiveQuery: String
      if let query = query, !query.isEmpty {
        effectiveQuery = String(query.prefix(settings.maxQueryLength))
        debugLog.log("Search", "Extracted text: \"\(effectiveQuery)\"", level: .info)
      } else {
        debugLog.log("Search", "No text extracted — showing panel with hint", level: .warning)
        effectiveQuery = ""
      }

      // Pass screenshot to AI provider before showing panel
      if let screenshot = textExtractorService?.lastScreenshot {
        ProviderRegistry.shared.aiSearchProvider.screenshotImage = screenshot
      }

      if searchPanelController == nil {
        searchPanelController = SearchPanelController()
      }

      searchPanelController?.show(query: effectiveQuery, at: position)
    }
  }

  // MARK: - Private

  private func setupServices() {
    // Event tap for force touch
    eventTapService = EventTapService()
    eventTapService?.mouseDownPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.textExtractorService?.snapshotSelection()
      }
      .store(in: &cancellables)
    eventTapService?.forceClickPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] point in
        self?.performSearch(at: point)
      }
      .store(in: &cancellables)

    // Always attempt to start — EventTapService.start() handles its own guards.
    // Permissions may be inherited (e.g. running from Xcode) even when
    // PermissionsService reports false, so let the tap/monitor try regardless.
    eventTapService?.start()

    // Text extractor
    textExtractorService = TextExtractorService()

    // Hotkey service
    hotKeyService = HotKeyService()
    hotKeyService?.hotKeyPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.performSearch(at: nil)
      }
      .store(in: &cancellables)
    if settings.hotKeyEnabled {
      hotKeyService?.register(keyCombo: settings.hotKey)
    }

    // Double-tap modifier service
    doubleTapService = DoubleTapService()
    doubleTapService?.doubleTapPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.performSearch(at: nil)
      }
      .store(in: &cancellables)
    if settings.doubleTapEnabled {
      doubleTapService?.start(modifier: settings.doubleTapModifier)
    }
  }

  private func observeSettings() {
    // Re-register hotkey when it changes
    settings.$hotKey
      .dropFirst()
      .sink { [weak self] newKey in
        guard let self = self else { return }
        if self.settings.hotKeyEnabled {
          self.hotKeyService?.register(keyCombo: newKey)
        }
      }
      .store(in: &cancellables)

    // Enable/disable hotkey
    settings.$hotKeyEnabled
      .dropFirst()
      .sink { [weak self] enabled in
        guard let self = self else { return }
        if enabled {
          self.hotKeyService?.register(keyCombo: self.settings.hotKey)
        } else {
          self.hotKeyService?.unregister()
        }
      }
      .store(in: &cancellables)

    // Enable/disable double-tap modifier
    settings.$doubleTapEnabled
      .dropFirst()
      .sink { [weak self] enabled in
        guard let self = self else { return }
        if enabled {
          self.doubleTapService?.start(modifier: self.settings.doubleTapModifier)
        } else {
          self.doubleTapService?.stop()
        }
      }
      .store(in: &cancellables)

    // Restart double-tap when modifier choice changes
    settings.$doubleTapModifier
      .dropFirst()
      .sink { [weak self] modifier in
        guard let self = self, self.settings.doubleTapEnabled else { return }
        self.doubleTapService?.start(modifier: modifier)
      }
      .store(in: &cancellables)

    // Enable/disable event tap based on force click setting
    settings.$forceClickEnabled
      .dropFirst()
      .sink { [weak self] enabled in
        if enabled {
          self?.eventTapService?.start()
        } else {
          self?.eventTapService?.stop()
        }
      }
      .store(in: &cancellables)

    // React to permission changes (only true→false or false→true transitions)
    permissions.$accessibilityGranted
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] granted in
        guard let self = self else { return }
        if granted, self.settings.forceClickEnabled {
          self.eventTapService?.restart()
        }
      }
      .store(in: &cancellables)
  }
}
