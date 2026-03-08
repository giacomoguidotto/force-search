import AppKit

enum AnimationConstants {
    enum PanelShow {
        static let springMass: CGFloat = 1.0
        static let springStiffness: CGFloat = 250
        static let springDamping: CGFloat = 22
        static let opacityDuration: TimeInterval = 0.2
        static let cursorTranslationFraction: CGFloat = 0.15
        static let initialScale: CGFloat = 0.82
        static let finalScale: CGFloat = 1.0
        static let initialAlpha: CGFloat = 0.0
        static let finalAlpha: CGFloat = 1.0
    }

    enum PanelDismiss {
        static let duration: TimeInterval = 0.15
        static let finalScale: CGFloat = 0.92
        static let finalAlpha: CGFloat = 0.0
        // Accelerating curve control points
        static let curveP1x: Float = 0.4
        static let curveP1y: Float = 0.0
        static let curveP2x: Float = 1.0
        static let curveP2y: Float = 1.0
    }

    enum TabSwitch {
        static let contentFadeDuration: TimeInterval = 0.15
        // Spring-like bezier for selection indicator
        static let springP1x: Float = 0.2
        static let springP1y: Float = 1.2
        static let springP2x: Float = 0.4
        static let springP2y: Float = 1.0
        static let springDuration: TimeInterval = 0.35
    }

    enum Loading {
        static let barHeight: CGFloat = 2
    }
}
