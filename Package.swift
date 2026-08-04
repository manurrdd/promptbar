// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Promptbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Promptbar",
            path: "Sources/Promptbar"
        )
    ]
)
