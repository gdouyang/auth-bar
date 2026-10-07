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
            path: "Sources/google_auth"
        ),
        .testTarget(
            name: "AuthBarTests",
            dependencies: ["AuthBar"],
            path: "Tests/google_authTests"
        ),
    ]
)
