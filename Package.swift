// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIProxy",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "AIProxy",
            targets: ["AIProxy"]),
    ],
    dependencies: [
        // No external dependencies for now - pure Swift implementation
    ],
    targets: [
        .target(
            name: "AIProxy",
            dependencies: ["AIProxyCore"],
            path: "Sources/AIProxy"
        ),
        .target(
            name: "AIProxyCore",
            dependencies: [],
            path: "Sources/AIProxyCore"
        ),
        .testTarget(
            name: "AIProxyTests",
            dependencies: ["AIProxy", "AIProxyCore"],
            path: "Tests/AIProxyTests"
        ),
    ]
)
