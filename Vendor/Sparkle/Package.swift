// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SparkleVendor",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "Sparkle",
            targets: ["Sparkle"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Sparkle",
            path: "Sparkle.xcframework"
        )
    ]
)
