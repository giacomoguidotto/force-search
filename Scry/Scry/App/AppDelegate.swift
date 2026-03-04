import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let settings = AppSettings.shared
  private let permissions = PermissionsService.shared
  private var onboardingController = OnboardingWindowController()
  private var preferencesController: PreferencesWindowController?
  private var debugConsoleController: DebugConsoleWindowController?
  private var eventTapService: EventTapService?
  private var textExtractorService: TextExtractorService?
  private var hotKeyService: HotKeyService?
  private var searchPanelController: SearchPanelController?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
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

  func showDebugConsole() {
    if debugConsoleController == nil {
      debugConsoleController = DebugConsoleWindowController()
    }
    debugConsoleController?.show()
  }

  func performSearch(at point: NSPoint?) {
    let debugLog = DebugLogStore.shared
    debugLog.log("Search", "performSearch called")

    let query = textExtractorService?.extractSelectedText()

    guard let query = query, !query.isEmpty else {
      debugLog.log("Search", "No text extracted — aborting")
      return
    }

    let truncatedQuery = String(query.prefix(settings.maxQueryLength))
    debugLog.log("Search", "Extracted text: \"\(truncatedQuery)\"")

    if searchPanelController == nil {
      searchPanelController = SearchPanelController()
    }

    let position = point ?? NSEvent.mouseLocation
    searchPanelController?.show(query: truncatedQuery, at: position)
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
    hotKeyService?.register(keyCombo: settings.hotKey)
  }

  private func observeSettings() {
    // Re-register hotkey when it changes
    settings.$hotKey
      .dropFirst()
      .sink { [weak self] newKey in
        self?.hotKeyService?.register(keyCombo: newKey)
      }
      .store(in: &cancellables)

    // Enable/disable event tap based on trigger method
    settings.$triggerMethod
      .dropFirst()
      .sink { [weak self] method in
        switch method {
        case .forceClick:
          self?.eventTapService?.start()
        case .hotKeyOnly:
          self?.eventTapService?.stop()
        }
      }
      .store(in: &cancellables)

    // Retry event tap when permissions change
    permissions.$accessibilityGranted
      .combineLatest(permissions.$inputMonitoringGranted)
      .dropFirst()
      .filter { $0.0 && $0.1 }
      .sink { [weak self] _ in
        guard let self = self else { return }
        if self.settings.triggerMethod == .forceClick {
          self.eventTapService?.restart()
        }
      }
      .store(in: &cancellables)
  }
}
