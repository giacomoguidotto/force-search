import AppKit
import Carbon

/// A unified trigger representation replacing separate doubleTap/hotKey properties.
enum Hotkey: Equatable {
    /// Single-tap a modifier key. Globe auto-detects single/double based on system conflict.
    case modifierTap(DoubleTapModifier)
    /// Explicitly double-tap a modifier key.
    case modifierDoubleTap(DoubleTapModifier)
    /// A key combination (e.g. Cmd+Shift+G).
    case keyCombo(KeyCombo)
    /// Disabled.
    case none

    // MARK: - Config String Parsing

    /// Parse a config string like "globe", "cmd cmd", "cmd+shift+g", or "".
    init(configString: String) {
        let trimmed = configString.trimmingCharacters(in: .whitespaces).lowercased()

        if trimmed.isEmpty {
            self = .none
            return
        }

        // Double-tap: "cmd cmd", "shift shift", etc.
        let words = trimmed.split(separator: " ").map(String.init)
        if words.count == 2, words[0] == words[1],
           let mod = Self.parseModifier(words[0]) {
            self = .modifierDoubleTap(mod)
            return
        }

        // Single modifier: "globe", "cmd", etc.
        if !trimmed.contains("+"), let mod = Self.parseModifier(trimmed) {
            self = .modifierTap(mod)
            return
        }

        // Key combo: "cmd+shift+g"
        let parts = trimmed.split(separator: "+").map(String.init)
        if parts.count >= 2 {
            var flags: NSEvent.ModifierFlags = []
            for part in parts.dropLast() {
                if let flag = Self.modifierFlag(for: part) {
                    flags.insert(flag)
                }
            }
            if !flags.isEmpty, let code = Self.keyCode(for: parts.last!) {
                self = .keyCombo(KeyCombo(keyCode: code, modifiers: flags))
                return
            }
        }

        self = .none
    }

    /// Serialize to a config string.
    var configString: String {
        switch self {
        case .modifierTap(let mod):
            return mod.configName
        case .modifierDoubleTap(let mod):
            return "\(mod.configName) \(mod.configName)"
        case .keyCombo(let combo):
            var parts: [String] = []
            let flags = combo.modifierFlags
            if flags.contains(.command) { parts.append("cmd") }
            if flags.contains(.control) { parts.append("ctrl") }
            if flags.contains(.option) { parts.append("opt") }
            if flags.contains(.shift) { parts.append("shift") }
            parts.append(combo.keyCodeString.lowercased())
            return parts.joined(separator: "+")
        case .none:
            return ""
        }
    }

    /// Human-readable label for UI display.
    var displayString: String {
        switch self {
        case .modifierTap(let mod):
            return mod.symbol
        case .modifierDoubleTap(let mod):
            return "\(mod.symbol) \(mod.symbol)"
        case .keyCombo(let combo):
            return combo.displayString
        case .none:
            return "None"
        }
    }

    /// Whether this hotkey involves the Globe key.
    var isGlobeTap: Bool {
        switch self {
        case .modifierTap(.globe), .modifierDoubleTap(.globe):
            return true
        default:
            return false
        }
    }

    // MARK: - Parsing Helpers

    private static let modifierNameMap: [String: DoubleTapModifier] = [
        "globe": .globe, "fn": .globe,
        "cmd": .command, "command": .command,
        "opt": .option, "option": .option,
        "ctrl": .control, "control": .control,
        "shift": .shift,
    ]

    private static func parseModifier(_ name: String) -> DoubleTapModifier? {
        modifierNameMap[name.lowercased()]
    }

    private static func modifierFlag(for name: String) -> NSEvent.ModifierFlags? {
        switch name.lowercased() {
        case "cmd", "command": return .command
        case "opt", "option": return .option
        case "ctrl", "control": return .control
        case "shift": return .shift
        default: return nil
        }
    }

    // swiftlint:disable:next closure_body_length
    private static let keyNameToCode: [String: UInt32] = {
        [
            "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
            "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
            "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
            "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
            "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
            "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
            "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
            "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
            "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
            "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
            "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
            "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
            "9": UInt32(kVK_ANSI_9),
            "space": UInt32(kVK_Space), "return": UInt32(kVK_Return),
            "escape": UInt32(kVK_Escape), "delete": UInt32(kVK_Delete),
            "tab": UInt32(kVK_Tab),
            "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3),
            "f4": UInt32(kVK_F4), "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6),
            "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8), "f9": UInt32(kVK_F9),
            "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        ]
    }()

    private static func keyCode(for name: String) -> UInt32? {
        keyNameToCode[name.lowercased()]
    }
}

// MARK: - DoubleTapModifier Config Name

extension DoubleTapModifier {
    var configName: String {
        switch self {
        case .globe: return "globe"
        case .command: return "cmd"
        case .option: return "opt"
        case .control: return "ctrl"
        case .shift: return "shift"
        }
    }
}
