// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ProxyKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v14),
        .tvOS(.v14),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "ProxyKit",
            targets: ["ProxyKit"]),
    ],
    dependencies: [
        // No external dependencies for now - pure Swift implementation
    ],
    targets: [
        .target(
            name: "ProxyKit",
            dependencies: ["ProxyKitAdvance", "ProxyKitCore"],
            path: "Sources/ProxyKit"
        ),
        .target(
            name: "ProxyKitAdvance",
            dependencies: ["ProxyKitCore"],
            path: "Sources/ProxyKitAdvance"
        ),
        .target(
            name: "ProxyKitCore",
            dependencies: [],
            path: "Sources/ProxyKitCore"
        )
    ]
)
