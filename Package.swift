// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "eventkitcli",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "eventkitcli", targets: ["eventkitcli"])
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
      .package(url: "https://github.com/batmac/SwiftyChrono", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "eventkitcli",
            dependencies: [
              .product(name: "ArgumentParser", package: "swift-argument-parser"),
              .product(name: "SwiftyChrono", package: "SwiftyChrono")
            ],
            path: "Sources"
        ),
    ]
)
