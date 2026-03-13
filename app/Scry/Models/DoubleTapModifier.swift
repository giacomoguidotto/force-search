import AppKit

enum DoubleTapModifier: String, Codable, CaseIterable, Identifiable {
    case globe
    case command
    case option
    case control
    case shift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .globe: return "Globe (fn)"
        case .command: return "Command (\u{2318})"
        case .option: return "Option (\u{2325})"
        case .control: return "Control (\u{2303})"
        case .shift: return "Shift (\u{21E7})"
        }
    }

    /// The keyCode to match in flagsChanged events.
    var keyCode: UInt16 {
        switch self {
        case .globe: return 63   // kVK_Function
        case .command: return 55 // kVK_Command (left); right is 54
        case .option: return 58  // kVK_Option (left); right is 61
        case .control: return 59 // kVK_Control (left); right is 62
        case .shift: return 56   // kVK_Shift (left); right is 60
        }
    }

    /// Alternative keyCode for the right-hand variant (nil for Globe).
    var rightKeyCode: UInt16? {
        switch self {
        case .globe: return nil
        case .command: return 54
        case .option: return 61
        case .control: return 62
        case .shift: return 60
        }
    }

    /// The modifier flag to check in NSEvent.modifierFlags.
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .globe: return .function
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }

    /// Whether this modifier requires the user to disable a system action first.
    var requiresSystemConfiguration: Bool {
        self == .globe
    }
}
