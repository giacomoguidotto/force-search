import Foundation
import AppKit
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Trigger

    @Published var triggerMethod: TriggerMethod = .forceClick {
        didSet { defaults.set(triggerMethod.rawValue, forKey: Keys.triggerMethod) }
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
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
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

    // MARK: - Init

    private typealias Keys = Constants.UserDefaultsKeys

    private init() {
        load()
    }

    private func load() {
        let d = defaults

        if let raw = d.string(forKey: Keys.triggerMethod), let val = TriggerMethod(rawValue: raw) {
            triggerMethod = val
        }

        let storedKeyCode = d.object(forKey: Keys.hotKeyKeyCode) as? UInt32
        let storedModifiers = d.object(forKey: Keys.hotKeyModifiers) as? UInt32
        if let kc = storedKeyCode, let mod = storedModifiers {
            hotKey = KeyCombo(keyCode: kc, modifiers: NSEvent.ModifierFlags.fromCarbon(mod))
        }

        if d.object(forKey: Keys.pressureSensitivity) != nil {
            pressureSensitivity = d.double(forKey: Keys.pressureSensitivity)
        }

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

        if d.object(forKey: Keys.launchAtLogin) != nil {
            launchAtLogin = d.bool(forKey: Keys.launchAtLogin)
        }
        if d.object(forKey: Keys.showMenuBarIcon) != nil {
            showMenuBarIcon = d.bool(forKey: Keys.showMenuBarIcon)
        }
        if let raw = d.string(forKey: Keys.menuBarIconStyle), let val = MenuBarIconStyle(rawValue: raw) {
            menuBarIconStyle = val
        }
        if d.object(forKey: Keys.hasCompletedOnboarding) != nil {
            hasCompletedOnboarding = d.bool(forKey: Keys.hasCompletedOnboarding)
        }
    }

    // MARK: - Export / Import

    func exportSettings() -> Data? {
        let dict: [String: Any] = [
            Keys.triggerMethod: triggerMethod.rawValue,
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
        ]
        return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    func importSettings(from data: Data) -> Bool {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let raw = dict[Keys.triggerMethod] as? String, let val = TriggerMethod(rawValue: raw) {
            triggerMethod = val
        }
        if let kc = dict[Keys.hotKeyKeyCode] as? UInt32, let mod = dict[Keys.hotKeyModifiers] as? UInt32 {
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
        if let raw = dict[Keys.openLinksIn] as? String, let val = LinkTarget(rawValue: raw) { openLinksIn = val }
        if let val = dict[Keys.showShortcutHints] as? Bool { showShortcutHints = val }
        if let val = dict[Keys.maxQueryLength] as? Int { maxQueryLength = val }
        if let val = dict[Keys.enabledProviders] as? [String] { enabledProviders = val }
        if let val = dict[Keys.providerOrder] as? [String] { providerOrder = val }
        if let val = dict[Keys.launchAtLogin] as? Bool { launchAtLogin = val }
        if let val = dict[Keys.showMenuBarIcon] as? Bool { showMenuBarIcon = val }
        if let raw = dict[Keys.menuBarIconStyle] as? String, let val = MenuBarIconStyle(rawValue: raw) { menuBarIconStyle = val }

        return true
    }

    /// The effective provider ID to use when opening a new panel.
    var effectiveProvider: String {
        if rememberLastProvider {
            return lastUsedProvider
        }
        return defaultProvider
    }
}
