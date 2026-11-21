// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HauteKey",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "HauteKeyCore"),
        .executableTarget(name: "HauteKey", dependencies: ["HauteKeyCore"]),
        .testTarget(name: "HauteKeyCoreTests", dependencies: ["HauteKeyCore"]),
    ]
)
