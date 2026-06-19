// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeetMode",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NeetMode",
            path: "Sources/NeetMode"
        )
    ]
)
