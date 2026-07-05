// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PicoManim",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "PicoManim",
            targets: ["PicoManim"]
        )
    ],
    targets: [
        .target(
            name: "PicoManim"
        ),
        .testTarget(
            name: "PicoManimTests",
            dependencies: ["PicoManim"]
        )
    ]
)
