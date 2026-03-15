import AppKit
import SwiftUI

enum ScryTheme {
    static let darkAppearance = NSAppearance(named: .darkAqua)!

    enum Colors {
        // Accent: #5DE4C7 (mint/teal)
        static let accent = NSColor(red: 0x5D / 255.0, green: 0xE4 / 255.0, blue: 0xC7 / 255.0, alpha: 1.0)

        // Error: #FF6B6B (warm red)
        static let error = NSColor(red: 0xFF / 255.0, green: 0x6B / 255.0, blue: 0x6B / 255.0, alpha: 1.0)

        // Text hierarchy
        static let textPrimary = NSColor(red: 0xE6 / 255.0, green: 0xE6 / 255.0, blue: 0xEA / 255.0, alpha: 1.0)
        static let textSecondary = NSColor(red: 0x80 / 255.0, green: 0x80 / 255.0, blue: 0x88 / 255.0, alpha: 1.0)
        static let textTertiary = NSColor(red: 0x58 / 255.0, green: 0x58 / 255.0, blue: 0x5F / 255.0, alpha: 1.0)

        // Panel border: accent at 12% opacity
        static let panelBorder = accent.withAlphaComponent(0.12)

        // Separator
        static let separator = NSColor.white.withAlphaComponent(0.08)

        // Tab bar
        static let tabSelectedFill = NSColor.white.withAlphaComponent(0.1)

        // SwiftUI bridge
        static var accentColor: Color { Color(nsColor: accent) }
        static var textPrimaryColor: Color { Color(nsColor: textPrimary) }
        static var textSecondaryColor: Color { Color(nsColor: textSecondary) }
        static var textTertiaryColor: Color { Color(nsColor: textTertiary) }
    }
}
