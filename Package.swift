// swift-tools-version:6.0
// QuotaBar — a macOS menu bar app with the usage limits of your AI coding CLIs.
// Build the app: scripts/build-app.sh <out-dir>
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "QuotaBar",
            path: "Sources/QuotaBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "QuotaBarTests", dependencies: ["QuotaBar"], path: "tests/QuotaBarTests")
    ]
)
