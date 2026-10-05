// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoogleAuthenticatorMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GoogleAuthenticatorMac", targets: ["GoogleAuthenticatorMac"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GoogleAuthenticatorMac",
            dependencies: [],
            path: "Sources/google_auth"
        ),
        .testTarget(
            name: "GoogleAuthenticatorMacTests",
            dependencies: ["GoogleAuthenticatorMac"],
            path: "Tests/google_authTests"
        ),
    ]
)
