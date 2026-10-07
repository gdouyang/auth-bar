// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuthBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AuthBar", targets: ["AuthBar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AuthBar",
            dependencies: [],
            path: "Sources/AuthBar"
        ),
        .testTarget(
            name: "AuthBarTests",
            dependencies: ["AuthBar"],
            path: "Tests/AuthBarTests"
        ),
    ]
)
