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
  private var searchPanelController: SearchPanelController?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self

    // Check permissions on launch
    permissions.checkAll()

    // Show onboarding if first run
    if !settings.hasCompletedOnboarding {
      onboardingController.show()
    }

    // Initialize services
    setupServices()

    // Watch for settings changes
    observeSettings()
  }

  func applicationWillTerminate(_ notification: Notification) {
    eventTapService?.stop()
    hotKeyService?.unregister()
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

    permissions.checkAll()
    if !permissions.allPermissionsGranted {
      debugLog.log("Search", "Missing permissions — showing onboarding", level: .warning)
      onboardingController.show()
      return
    }

    let position = point ?? NSEvent.mouseLocation

    // Instant visual feedback before async work begins
    RippleOverlay.show(at: position)

    Task { @MainActor in
      let query = await textExtractorService?.extractText(at: position)

      guard let query = query, !query.isEmpty else {
        debugLog.log("Search", "No text extracted — aborting", level: .warning)
        return
      }

      let truncatedQuery = String(query.prefix(settings.maxQueryLength))
      debugLog.log("Search", "Extracted text: \"\(truncatedQuery)\"", level: .info)

      // Pass screenshot to AI provider before showing panel
      if let screenshot = textExtractorService?.lastScreenshot {
        ProviderRegistry.shared.aiSearchProvider.screenshotImage = screenshot
      }

      if searchPanelController == nil {
        searchPanelController = SearchPanelController()
      }

      searchPanelController?.show(query: truncatedQuery, at: position)
    }
  }

  // MARK: - Private

  private func setupServices() {
    // Event tap for force touch
    eventTapService = EventTapService()
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

    // React to permission changes
    permissions.$accessibilityGranted
      .combineLatest(permissions.$inputMonitoringGranted, permissions.$screenRecordingGranted)
      .map { $0.0 && $0.1 && $0.2 }
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] allGranted in
        guard let self = self else { return }
        if allGranted {
          // Retry event tap when permissions become granted
          if self.settings.forceClickEnabled {
            self.eventTapService?.restart()
          }
        } else {
          // Permissions revoked — show onboarding so user can re-grant
          self.onboardingController.show()
        }
      }
      .store(in: &cancellables)
  }
}
