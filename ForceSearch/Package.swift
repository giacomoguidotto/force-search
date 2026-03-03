// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ForceSearch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ForceSearch",
            path: "ForceSearch",
            exclude: ["App/Info.plist", "App/ForceSearch.entitlements"],
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
            name: "ForceSearchTests",
            dependencies: ["ForceSearch"],
            path: "ForceSearchTests"
        ),
    ]
)
