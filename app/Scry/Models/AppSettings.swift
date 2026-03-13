import AppKit
import Combine
import Foundation
import ServiceManagement

final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private let defaults = UserDefaults.standard
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Trigger

  @Published var forceClickEnabled: Bool = true {
    didSet { defaults.set(forceClickEnabled, forKey: Keys.forceClickEnabled) }
  }

  @Published var doubleTapEnabled: Bool = true {
    didSet { defaults.set(doubleTapEnabled, forKey: Keys.doubleTapEnabled) }
  }

  @Published var doubleTapModifier: DoubleTapModifier = .globe {
    didSet { defaults.set(doubleTapModifier.rawValue, forKey: Keys.doubleTapModifier) }
  }

  @Published var hotKeyEnabled: Bool = false {
    didSet { defaults.set(hotKeyEnabled, forKey: Keys.hotKeyEnabled) }
  }

  @Published var hotKey: KeyCombo = .default {
    didSet {
      defaults.set(hotKey.keyCode, forKey: Keys.hotKeyKeyCode)
      defaults.set(hotKey.modifiers, forKey: Keys.hotKeyModifiers)
    }
  }

  @Published var pressureSensitivity: Double = Constants.Defaults.pressureSensitivity {
    didSet { defaults.set(pressureSensitivity, forKey: Keys.pressureSensitivity) }
  }

  // MARK: - Appearance

  @Published var panelWidth: CGFloat = Constants.Panel.defaultWidth {
    didSet { defaults.set(panelWidth, forKey: Keys.panelWidth) }
  }

  @Published var panelHeight: CGFloat = Constants.Panel.defaultHeight {
    didSet { defaults.set(panelHeight, forKey: Keys.panelHeight) }
  }

  @Published var panelOpacity: Double = 1.0 {
    didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
  }

  @Published var cornerRadius: CGFloat = Constants.Panel.defaultCornerRadius {
    didSet { defaults.set(cornerRadius, forKey: Keys.cornerRadius) }
  }

  @Published var showAnimations: Bool = true {
    didSet { defaults.set(showAnimations, forKey: Keys.showAnimations) }
  }

  @Published var theme: Theme = .system {
    didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
  }

  // MARK: - Behavior

  @Published var defaultProvider: String = Constants.Defaults.defaultProvider {
    didSet { defaults.set(defaultProvider, forKey: Keys.defaultProvider) }
  }

  @Published var rememberLastProvider: Bool = true {
    didSet { defaults.set(rememberLastProvider, forKey: Keys.rememberLastProvider) }
  }

  @Published var lastUsedProvider: String = Constants.Defaults.defaultProvider {
    didSet { defaults.set(lastUsedProvider, forKey: Keys.lastUsedProvider) }
  }

  @Published var dismissOnLinkClick: Bool = true {
    didSet { defaults.set(dismissOnLinkClick, forKey: Keys.dismissOnLinkClick) }
  }

  @Published var openLinksIn: LinkTarget = .defaultBrowser {
    didSet { defaults.set(openLinksIn.rawValue, forKey: Keys.openLinksIn) }
  }

  @Published var showShortcutHints: Bool = true {
    didSet { defaults.set(showShortcutHints, forKey: Keys.showShortcutHints) }
  }

  @Published var maxQueryLength: Int = Constants.Timing.maxQueryLength {
    didSet { defaults.set(maxQueryLength, forKey: Keys.maxQueryLength) }
  }

  // MARK: - Providers

  @Published var enabledProviders: [String] = Constants.Defaults.enabledProviders {
    didSet { defaults.set(enabledProviders, forKey: Keys.enabledProviders) }
  }

  @Published var providerOrder: [String] = Constants.Defaults.enabledProviders {
    didSet { defaults.set(providerOrder, forKey: Keys.providerOrder) }
  }

  // MARK: - System

  @Published var launchAtLogin: Bool = false {
    didSet {
      defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
      updateLaunchAtLogin()
    }
  }

  @Published var showMenuBarIcon: Bool = true {
    didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
  }

  @Published var menuBarIconStyle: MenuBarIconStyle = .magnifyingGlass {
    didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Keys.menuBarIconStyle) }
  }

  @Published var hasCompletedOnboarding: Bool = false {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
  }

  // MARK: - AI

  @Published var aiEnabled: Bool = false {
    didSet { defaults.set(aiEnabled, forKey: Keys.aiEnabled) }
  }

  @Published var aiProviderType: AIProviderType = .claude {
    didSet { defaults.set(aiProviderType.rawValue, forKey: Keys.aiProviderType) }
  }

  @Published var aiAPIKey: String = "" {
    didSet { defaults.set(aiAPIKey, forKey: Keys.aiAPIKey) }
  }

  @Published var aiModel: String = Constants.AIConfig.defaultClaudeModel {
    didSet { defaults.set(aiModel, forKey: Keys.aiModel) }
  }

  @Published var aiCustomEndpoint: String = "" {
    didSet { defaults.set(aiCustomEndpoint, forKey: Keys.aiCustomEndpoint) }
  }

  @Published var screenshotRegionSize: CGFloat = Constants.Screenshot.defaultRegionSize {
    didSet { defaults.set(screenshotRegionSize, forKey: Keys.screenshotRegionSize) }
  }

  // MARK: - Init

  private typealias Keys = Constants.UserDefaultsKeys

  private init() {
    load()
  }

  private func load() {
    let d = defaults
    loadTriggerSettings(from: d)
    loadAppearanceSettings(from: d)
    loadBehaviorSettings(from: d)
    loadSystemSettings(from: d)
    loadAISettings(from: d)
  }

  private func loadTriggerSettings(from d: UserDefaults) {
    // Migrate legacy triggerMethod → forceClickEnabled
    if d.object(forKey: Keys.forceClickEnabled) != nil {
      forceClickEnabled = d.bool(forKey: Keys.forceClickEnabled)
    } else if let raw = d.string(forKey: Keys.triggerMethod) {
      forceClickEnabled = (raw == "forceClick")
    }
    if d.object(forKey: Keys.doubleTapEnabled) != nil {
      doubleTapEnabled = d.bool(forKey: Keys.doubleTapEnabled)
    }
    if let raw = d.string(forKey: Keys.doubleTapModifier),
       let val = DoubleTapModifier(rawValue: raw) {
      doubleTapModifier = val
    }
    if d.object(forKey: Keys.hotKeyEnabled) != nil {
      hotKeyEnabled = d.bool(forKey: Keys.hotKeyEnabled)
    }

    let storedKeyCode = d.object(forKey: Keys.hotKeyKeyCode) as? UInt32
    let storedModifiers = d.object(forKey: Keys.hotKeyModifiers) as? UInt32
    if let kc = storedKeyCode, let mod = storedModifiers {
      hotKey = KeyCombo(keyCode: kc, modifiers: NSEvent.ModifierFlags.fromCarbon(mod))
    }

    if d.object(forKey: Keys.pressureSensitivity) != nil {
      pressureSensitivity = d.double(forKey: Keys.pressureSensitivity)
    }
  }

  private func loadAppearanceSettings(from d: UserDefaults) {
    if d.object(forKey: Keys.panelWidth) != nil {
      panelWidth = d.double(forKey: Keys.panelWidth)
    }
    if d.object(forKey: Keys.panelHeight) != nil {
      panelHeight = d.double(forKey: Keys.panelHeight)
    }
    if d.object(forKey: Keys.panelOpacity) != nil {
      panelOpacity = d.double(forKey: Keys.panelOpacity)
    }
    if d.object(forKey: Keys.cornerRadius) != nil {
      cornerRadius = d.double(forKey: Keys.cornerRadius)
    }
    if d.object(forKey: Keys.showAnimations) != nil {
      showAnimations = d.bool(forKey: Keys.showAnimations)
    }
    if let raw = d.string(forKey: Keys.theme), let val = Theme(rawValue: raw) {
      theme = val
    }
  }

  private func loadBehaviorSettings(from d: UserDefaults) {
    if let val = d.string(forKey: Keys.defaultProvider) {
      defaultProvider = val
    }
    if d.object(forKey: Keys.rememberLastProvider) != nil {
      rememberLastProvider = d.bool(forKey: Keys.rememberLastProvider)
    }
    if let val = d.string(forKey: Keys.lastUsedProvider) {
      lastUsedProvider = val
    }
    if d.object(forKey: Keys.dismissOnLinkClick) != nil {
      dismissOnLinkClick = d.bool(forKey: Keys.dismissOnLinkClick)
    }
    if let raw = d.string(forKey: Keys.openLinksIn), let val = LinkTarget(rawValue: raw) {
      openLinksIn = val
    }
    if d.object(forKey: Keys.showShortcutHints) != nil {
      showShortcutHints = d.bool(forKey: Keys.showShortcutHints)
    }
    if d.object(forKey: Keys.maxQueryLength) != nil {
      maxQueryLength = d.integer(forKey: Keys.maxQueryLength)
    }
    if let val = d.array(forKey: Keys.enabledProviders) as? [String] {
      enabledProviders = val
    }
    if let val = d.array(forKey: Keys.providerOrder) as? [String] {
      providerOrder = val
    }
  }

  private func loadSystemSettings(from d: UserDefaults) {
    if d.object(forKey: Keys.launchAtLogin) != nil {
      launchAtLogin = d.bool(forKey: Keys.launchAtLogin)
    }
    if d.object(forKey: Keys.showMenuBarIcon) != nil {
      showMenuBarIcon = d.bool(forKey: Keys.showMenuBarIcon)
    }
    if let raw = d.string(forKey: Keys.menuBarIconStyle),
       let val = MenuBarIconStyle(rawValue: raw) {
      menuBarIconStyle = val
    }
    if d.object(forKey: Keys.hasCompletedOnboarding) != nil {
      hasCompletedOnboarding = d.bool(forKey: Keys.hasCompletedOnboarding)
    }
  }

  private func loadAISettings(from d: UserDefaults) {
    if d.object(forKey: Keys.aiEnabled) != nil {
      aiEnabled = d.bool(forKey: Keys.aiEnabled)
    }
    if let raw = d.string(forKey: Keys.aiProviderType), let val = AIProviderType(rawValue: raw) {
      aiProviderType = val
    }
    if let val = d.string(forKey: Keys.aiAPIKey) { aiAPIKey = val }
    if let val = d.string(forKey: Keys.aiModel), !val.isEmpty { aiModel = val }
    if let val = d.string(forKey: Keys.aiCustomEndpoint) { aiCustomEndpoint = val }
    if d.object(forKey: Keys.screenshotRegionSize) != nil {
      screenshotRegionSize = d.double(forKey: Keys.screenshotRegionSize)
    }
  }

  // MARK: - Export / Import

  func exportSettings() -> Data? {
    let dict: [String: Any] = [
      Keys.forceClickEnabled: forceClickEnabled,
      Keys.doubleTapEnabled: doubleTapEnabled,
      Keys.doubleTapModifier: doubleTapModifier.rawValue,
      Keys.hotKeyEnabled: hotKeyEnabled,
      Keys.hotKeyKeyCode: hotKey.keyCode,
      Keys.hotKeyModifiers: hotKey.modifiers,
      Keys.pressureSensitivity: pressureSensitivity,
      Keys.panelWidth: panelWidth,
      Keys.panelHeight: panelHeight,
      Keys.panelOpacity: panelOpacity,
      Keys.cornerRadius: cornerRadius,
      Keys.showAnimations: showAnimations,
      Keys.theme: theme.rawValue,
      Keys.defaultProvider: defaultProvider,
      Keys.rememberLastProvider: rememberLastProvider,
      Keys.dismissOnLinkClick: dismissOnLinkClick,
      Keys.openLinksIn: openLinksIn.rawValue,
      Keys.showShortcutHints: showShortcutHints,
      Keys.maxQueryLength: maxQueryLength,
      Keys.enabledProviders: enabledProviders,
      Keys.providerOrder: providerOrder,
      Keys.launchAtLogin: launchAtLogin,
      Keys.showMenuBarIcon: showMenuBarIcon,
      Keys.menuBarIconStyle: menuBarIconStyle.rawValue,
      Keys.aiEnabled: aiEnabled,
      Keys.aiProviderType: aiProviderType.rawValue,
      Keys.aiAPIKey: aiAPIKey,
      Keys.aiModel: aiModel,
      Keys.aiCustomEndpoint: aiCustomEndpoint,
      Keys.screenshotRegionSize: screenshotRegionSize,
    ]
    return try? JSONSerialization.data(
      withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
  }

  func importSettings(from data: Data) -> Bool {
    guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return false
    }

    if let val = dict[Keys.forceClickEnabled] as? Bool { forceClickEnabled = val }
    if let val = dict[Keys.doubleTapEnabled] as? Bool { doubleTapEnabled = val }
    if let raw = dict[Keys.doubleTapModifier] as? String,
       let val = DoubleTapModifier(rawValue: raw) { doubleTapModifier = val }
    if let val = dict[Keys.hotKeyEnabled] as? Bool { hotKeyEnabled = val }
    if let kc = dict[Keys.hotKeyKeyCode] as? UInt32,
       let mod = dict[Keys.hotKeyModifiers] as? UInt32 {
      hotKey = KeyCombo(keyCode: kc, modifiers: NSEvent.ModifierFlags.fromCarbon(mod))
    }
    if let val = dict[Keys.pressureSensitivity] as? Double { pressureSensitivity = val }
    if let val = dict[Keys.panelWidth] as? CGFloat { panelWidth = val }
    if let val = dict[Keys.panelHeight] as? CGFloat { panelHeight = val }
    if let val = dict[Keys.panelOpacity] as? Double { panelOpacity = val }
    if let val = dict[Keys.cornerRadius] as? CGFloat { cornerRadius = val }
    if let val = dict[Keys.showAnimations] as? Bool { showAnimations = val }
    if let raw = dict[Keys.theme] as? String, let val = Theme(rawValue: raw) { theme = val }
    if let val = dict[Keys.defaultProvider] as? String { defaultProvider = val }
    if let val = dict[Keys.rememberLastProvider] as? Bool { rememberLastProvider = val }
    if let val = dict[Keys.dismissOnLinkClick] as? Bool { dismissOnLinkClick = val }
    if let raw = dict[Keys.openLinksIn] as? String, let val = LinkTarget(rawValue: raw) {
      openLinksIn = val
    }
    if let val = dict[Keys.showShortcutHints] as? Bool { showShortcutHints = val }
    if let val = dict[Keys.maxQueryLength] as? Int { maxQueryLength = val }
    if let val = dict[Keys.enabledProviders] as? [String] { enabledProviders = val }
    if let val = dict[Keys.providerOrder] as? [String] { providerOrder = val }
    if let val = dict[Keys.launchAtLogin] as? Bool { launchAtLogin = val }
    if let val = dict[Keys.showMenuBarIcon] as? Bool { showMenuBarIcon = val }
    if let raw = dict[Keys.menuBarIconStyle] as? String, let val = MenuBarIconStyle(rawValue: raw) {
      menuBarIconStyle = val
    }
    importAISettings(from: dict)
    return true
  }

  private func importAISettings(from dict: [String: Any]) {
    if let val = dict[Keys.aiEnabled] as? Bool { aiEnabled = val }
    if let raw = dict[Keys.aiProviderType] as? String, let val = AIProviderType(rawValue: raw) {
      aiProviderType = val
    }
    if let val = dict[Keys.aiAPIKey] as? String { aiAPIKey = val }
    if let val = dict[Keys.aiModel] as? String { aiModel = val }
    if let val = dict[Keys.aiCustomEndpoint] as? String { aiCustomEndpoint = val }
    if let val = dict[Keys.screenshotRegionSize] as? CGFloat { screenshotRegionSize = val }
  }

  /// The effective provider ID to use when opening a new panel.
  var effectiveProvider: String {
    if rememberLastProvider {
      return lastUsedProvider
    }
    return defaultProvider
  }

  // MARK: - Launch at Login

  private func updateLaunchAtLogin() {
    let service = SMAppService.mainApp
    do {
      if launchAtLogin {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      DebugLogStore.shared.log("Settings", "Launch at login failed: \(error.localizedDescription)", level: .error)
    }
  }
}
