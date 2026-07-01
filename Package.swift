// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapCraft",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // In-app auto-update framework (the "Check for Updates…" flow).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "SnapCraft",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SnapCraft",
            swiftSettings: [
                // The app drives its own AppKit lifecycle pieces (status item,
                // global hot keys) so we keep the default actor isolation relaxed.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                // Sparkle ships as an XCFramework that build-app.sh copies into
                // SnapCraft.app/Contents/Frameworks. This rpath lets the embedded
                // executable find it at runtime.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
