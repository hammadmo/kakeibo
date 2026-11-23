// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kakeibo",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Self-updates, like Hachibu (Updates.swift).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "KakeiboKit"),
        .executableTarget(
            name: "Kakeibo",
            dependencies: ["KakeiboKit", .product(name: "Sparkle", package: "Sparkle")],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "KakeiboKitTests", dependencies: ["KakeiboKit"]),
    ]
)
