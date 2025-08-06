// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecureProxy",
    platforms: [
        .iOS(.v14),
        .macOS(.v14),
        .tvOS(.v14),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "SecureProxy",
            targets: ["SecureProxy"]),
    ],
    dependencies: [
        // No external dependencies for now - pure Swift implementation
    ],
    targets: [
        .target(
            name: "SecureProxy",
            dependencies: ["AIProxy", "ProxyKitCore"],
            path: "Sources/SecureProxy"
        ),
        .target(
            name: "AIProxy",
            dependencies: ["ProxyKitCore"],
            path: "Sources/AIProxy"
        ),
        .target(
            name: "ProxyKitCore",
            dependencies: [],
            path: "Sources/ProxyKitCore"
        ),
        .testTarget(
            name: "AIProxyTests",
            dependencies: ["AIProxy", "ProxyKitCore"],
            path: "Tests/AIProxyTests"
        ),
    ]
)
