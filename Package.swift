// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchApple",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchApple",
            path: "Sources/NotchApple",
            resources: [.process("Resources")]
        )
    ]
)

