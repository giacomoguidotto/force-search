// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scry",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Scry",
            path: "Scry",
            exclude: ["App/Info.plist", "App/Scry.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("NaturalLanguage"),
            ]
        ),
        .testTarget(
            name: "ScryTests",
            dependencies: ["Scry"],
            path: "ScryTests"
        ),
    ]
)
