// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmartIsland",
            path: "Sources/SmartIsland"
        )
    ]
)
