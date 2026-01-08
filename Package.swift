// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubNotifier",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .target(
            name: "GitHubNotifierCore",
            dependencies: [],
            path: "Sources/GitHubNotifierCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "GitHubNotifier",
            dependencies: [
                "GitHubNotifierCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/GitHubNotifier",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/en.lproj"),
                .copy("Resources/zh-Hans.lproj"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/GitHubNotifier/Info.plist",
                ]),
            ]
        ),
    ]
)
