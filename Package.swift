// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChibiDeck",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "PanelCore",
            resources: [.copy("Resources/Mascots"), .copy("Resources/Themes")]
        ),
        .executableTarget(
            name: "ChibiDeck",
            dependencies: ["PanelCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "PanelCoreTests", dependencies: ["PanelCore"]),
    ]
)
