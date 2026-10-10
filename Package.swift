// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "H3",
    platforms: [
        .iOS(.v12),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "H3", targets: ["H3"]),
        .library(name: "H3Extended", targets: ["H3Extended"])
    ],
    targets: [
        .target(
            name: "CH3",
            path: ".",
            sources: ["src/h3lib/lib"],
            publicHeadersPath: "bindings/swift/include",
            cSettings: [
                .headerSearchPath("src/h3lib/include"),
                .headerSearchPath("bindings/swift/include"),
                .define("BUILDING_H3", to: "1"),
                .define("H3_HAVE_ALLOCA", to: "1"),
                .define("H3_HAVE_VLA", to: "1")
            ]
        ),
        .target(
            name: "CH3Extended",
            path: "bindings/extended",
            sources: ["lib", "bridge.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../src/h3lib/include"),
                .headerSearchPath("../swift/include"),
                .define("H3_EXTENDED", to: "1"),
                .define("BUILDING_H3", to: "1"),
                .define("H3_HAVE_ALLOCA", to: "1"),
                .define("H3_HAVE_VLA", to: "1")
            ]
        ),
        .target(
            name: "H3",
            dependencies: ["CH3"],
            path: "bindings/swift/Sources/H3"
        ),
        .target(
            name: "H3Extended",
            dependencies: ["H3", "CH3Extended"],
            path: "bindings/swift/Sources/H3Extended"
        ),
        .testTarget(
            name: "H3Tests",
            dependencies: ["H3", "H3Extended"],
            path: "bindings/swift/Tests/H3Tests"
        )
    ],
    cLanguageStandard: .gnu11
)
