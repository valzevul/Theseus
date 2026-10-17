// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theseus",
    platforms: [
        // iOS 13 is the floor: Metal is iOS 13+ in the simulator SDK slice, so
        // a lower target does not build for the simulator.
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Theseus",
            targets: ["Theseus"]
        ),
    ],
    targets: [
        .target(
            name: "Theseus",
            resources: [
                .process("Shaders")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("IOSurface")
            ]
        ),
        .testTarget(
            name: "TheseusTests",
            dependencies: ["Theseus"]
        ),
    ]
)
