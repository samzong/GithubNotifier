// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubNotifier",
    platforms: [
        .macOS(.v14),  // Required for @Observable macro
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .executableTarget(
            name: "GitHubNotifier",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/GitHubNotifier",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/en.lproj"),
                .copy("Resources/zh-Hans.lproj"),
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
