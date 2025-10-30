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

## Development
- Fetch dependencies and build: `swift build`
- Run tests: `swift test`

## License
The upstream H3 library is licensed under Apache License 2.0 (see `LICENSE` and `NOTICE`). This Swift wrapper preserves the same license; retain the attribution files when redistributing and document any modifications as required by the upstream terms. This README does not constitute legal advice—consult a professional for compliance questions.
