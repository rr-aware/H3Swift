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
        .library(name: "H3", targets: ["H3"])
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
            name: "H3",
            dependencies: ["CH3"],
            path: "bindings/swift/Sources/H3"
        ),
        .testTarget(
            name: "H3Tests",
            dependencies: ["H3"],
            path: "bindings/swift/Tests/H3Tests"
        )
    ],
    cLanguageStandard: .gnu11
)
