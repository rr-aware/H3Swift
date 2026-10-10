# H3 Swift

Swift Package Manager wrapper for Uber's [H3](https://h3geo.org/) hexagonal hierarchical geospatial indexing system. This package exposes common H3 functionality through a Swifty API while vendoring the original C implementation for Apple platforms.

## Requirements
- Swift 5.9 or later
- iOS 12, macOS 11, tvOS 13, or watchOS 6 minimum deployment targets

## Installation
Add `H3` as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rr-aware/H3Swift.git", from: "0.1.0")
]
```

and include it in your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "H3", package: "H3Swift")
    ]
)
```

## Usage
```swift
import H3

let coord = GeoCoord(latitude: 37.775938728915946, longitude: -122.41795063018799)
let index = try H3.index(from: coord, resolution: 9)

let center = try H3.coordinate(for: index)
let neighbors = try H3.gridDisk(origin: index, k: 2)
```

The `H3` namespace mirrors commonly used functions from the C library and throws `H3LibraryError` when the underlying call fails.

## Extended grid: 20 resolutions (0...19)

This fork also provides an optional `H3Extended` product. Add it to your app target:

```swift
.product(name: "H3Extended", package: "H3Swift")
```

Then use the extended namespace:

```swift
import H3Extended // Also exports the original H3 coordinate and error types.

let coordinate = GeoCoord(latitude: 35.681236, longitude: 139.767125)
let cell = try H3Extended.index(from: coordinate, resolution: 19)
let center = try H3Extended.coordinate(for: cell)
let boundary = try H3Extended.boundary(for: cell)
let neighbors = try H3Extended.gridDisk(origin: cell, k: 1)
let area = try H3Extended.cellAreaM2(cell)
let stored = try H3Extended.string(from: cell) // "h3x1:..."
let restored = try H3Extended.index(from: stored)

// Convert to an interoperable standard H3 parent explicitly.
let parent = try H3Extended.parent(of: cell, resolution: 15)
let standard: H3Index = try H3Extended.standardIndex(from: parent)
let extendedAgain = try H3Extended.index(fromStandard: standard)
```

The original `H3` product, `UInt64` indexes, strings, and resolution range remain
unchanged. Extended indexes are **a custom format, not official H3 indexes**.
`H3ExtendedIndex` is a hashable, sendable pair of `UInt64` words, with `Codable`
encoding as a versioned `h3x1:` hexadecimal string. Store that string when crossing
JSON/database boundaries; do not truncate it to `UInt64` or a JSON number.
Conversions at resolutions 0...15 are lossless. Converting a finer index directly
to standard H3 throws `E_RES_DOMAIN`; first select an appropriate parent.

The extended API covers coordinate indexing, centers, boundaries, cell validation,
pentagon detection, resolution, parents, descendants, grid disks/distances, cell
areas, and serialization. It retains H3's hierarchy and pentagon behavior, including
cases where grid distance is undefined. Extended polygon filling, directed edges,
vertices, and compaction are not exposed as supported public APIs.

Each additional level divides typical area by about 7 and edge length by about
√7. Four extra levels therefore give about 2,401 times smaller area and 49 times
shorter edges; estimated average edge length at resolution 19 is about 1.2 cm.
This is grid size, not a guarantee of input coordinate or positioning accuracy.

`childrenCount` lets you inspect descendant counts without allocation. Array-returning
extended APIs default to a maximum of 1,000,000 results and throw `E_MEMORY_BOUNDS`
above that limit; override `maximumCount` deliberately when needed.

Swift 5.9 and the existing deployment targets remain supported. The optional
extended engine requires a Clang target with 128-bit integer support (including
arm64, arm64_32, and x86_64); it does not support legacy armv7k watches. Apps using
only the original `H3` product do not build or link the extended engine.
See [the implementation notes](bindings/extended/README.md) for the index layout
and upstream maintenance instructions.

## Development
- Fetch dependencies and build: `swift build`
- Run Swift compatibility and extended-grid tests: `swift test`
- Run the C engine with AddressSanitizer and UndefinedBehaviorSanitizer: `scripts/test-extended-c.sh`

## License
The upstream H3 library is licensed under Apache License 2.0 (see `LICENSE` and `NOTICE`). This Swift wrapper preserves the same license; retain the attribution files when redistributing and document any modifications as required by the upstream terms. This README does not constitute legal advice—consult a professional for compliance questions.
