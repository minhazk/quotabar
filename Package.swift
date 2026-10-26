// swift-tools-version:6.0
// LeftBar — a macOS menu bar app with the usage limits of your AI coding CLIs.
// Build the app: scripts/build-app.sh <out-dir>
import PackageDescription

let package = Package(
    name: "LeftBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LeftBar",
            path: "Sources/LeftBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "LeftBarTests", dependencies: ["LeftBar"], path: "tests/LeftBarTests")
    ]
)
