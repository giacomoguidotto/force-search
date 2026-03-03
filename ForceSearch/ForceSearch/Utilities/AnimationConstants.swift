import AppKit

enum AnimationConstants {
    enum PanelShow {
        static let duration: TimeInterval = 0.2
        static let springResponse: CGFloat = 0.3
        static let springDamping: CGFloat = 0.8
        static let initialScale: CGFloat = 0.97
        static let finalScale: CGFloat = 1.0
        static let initialAlpha: CGFloat = 0.0
        static let finalAlpha: CGFloat = 1.0
    }

    enum PanelDismiss {
        static let duration: TimeInterval = 0.12
        static let finalScale: CGFloat = 0.97
        static let finalAlpha: CGFloat = 0.0
    }

    enum TabSwitch {
        static let duration: TimeInterval = 0.15
    }

    enum Loading {
        static let barHeight: CGFloat = 2
    }
}
