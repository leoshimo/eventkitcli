// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
    name: "eventkitcli",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "eventkitcli", targets: ["eventkitcli"])
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.3.0"),
      .package(url: "https://github.com/batmac/SwiftyChrono", revision: "e1bf3bde0f09112909157360b6bf39302f10ae5f")
    ],
    targets: [
        .executableTarget(
            name: "eventkitcli",
            dependencies: [
              .product(name: "ArgumentParser", package: "swift-argument-parser"),
              .product(name: "SwiftyChrono", package: "SwiftyChrono")
            ],
            path: "Sources",
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                "-Xlinker", packageDirectory + "/Resources/Info.plist"
            ])]
        ),
        .testTarget(name: "eventkitcliTests", dependencies: ["eventkitcli"], path: "Tests"),
    ]
)
