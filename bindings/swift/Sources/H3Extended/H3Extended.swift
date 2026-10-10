@_exported import H3
import CH3Extended
import Foundation

/// An index in this package's extended H3 grid (resolutions 0...19).
/// This is a distinct format from standard H3 UInt64 indexes. Use explicit
/// conversions or the versioned `h3x1:` string representation for persistence.
public struct H3ExtendedIndex: Equatable, Hashable, Sendable, Codable {
    public let high: UInt64
    public let low: UInt64

    /// Creates a raw index. Validate untrusted bits with `H3Extended.isValidCell`.
    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    fileprivate init(_ bits: H3ExtendedBits) {
        self.init(high: bits.high, low: bits.low)
    }

    fileprivate var bits: H3ExtendedBits { H3ExtendedBits(high: high, low: low) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do { self = try H3Extended.index(from: string) }
        catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid extended H3 index")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(H3Extended.string(from: self))
    }
}

public struct H3ExtendedGridDiskEntry: Equatable, Hashable, Sendable {
    public let index: H3ExtendedIndex
    public let distance: Int
}

/// Extended aperture-7 H3 grid with 20 levels. Standard H3 APIs remain on `H3`.
/// Extended indexes cannot be passed directly to upstream H3 libraries.
public enum H3Extended {
    public static let resolutions = 0...19
    public static let nullIndex = H3ExtendedIndex(high: 0, low: 0)

    public static func index(from coordinate: GeoCoord, resolution: Int) throws -> H3ExtendedIndex {
        let res = try checkedResolution(resolution)
        let g = H3ExtendedLatLng(lat: coordinate.latitude * .pi / 180, lng: coordinate.longitude * .pi / 180)
        var out = nullIndex.bits
        try check(h3eFromLatLng(g, res, &out))
        return H3ExtendedIndex(out)
    }

    public static func coordinate(for index: H3ExtendedIndex) throws -> GeoCoord {
        var out = H3ExtendedLatLng()
        try check(h3eToLatLng(index.bits, &out))
        return GeoCoord(latitude: out.lat, longitude: out.lng, unit: .radians)
    }

    public static func boundary(for index: H3ExtendedIndex) throws -> GeoBoundary {
        var out = H3ExtendedBoundary()
        try check(h3eBoundary(index.bits, &out))
        let vertices = Mirror(reflecting: out.verts).children
            .compactMap { $0.value as? H3ExtendedLatLng }
            .prefix(Int(out.numVerts))
            .map { GeoCoord(latitude: $0.lat, longitude: $0.lng, unit: .radians) }
        return GeoBoundary(vertices: Array(vertices))
    }

    public static func isValidCell(_ index: H3ExtendedIndex) -> Bool { h3eIsValid(index.bits) != 0 }
    public static func isPentagon(_ index: H3ExtendedIndex) -> Bool { h3eIsPentagon(index.bits) != 0 }
    public static func resolution(of index: H3ExtendedIndex) -> Int { Int(h3eResolution(index.bits)) }

    public static func parent(of index: H3ExtendedIndex, resolution: Int) throws -> H3ExtendedIndex {
        let res = try checkedResolution(resolution)
        var out = nullIndex.bits
        try check(h3eParent(index.bits, res, &out))
        return H3ExtendedIndex(out)
    }

    /// Number of descendants; use this before allocating a large result array.
    public static func childrenCount(of index: H3ExtendedIndex, resolution: Int) throws -> Int64 {
        let res = try checkedResolution(resolution)
        var count: Int64 = 0
        try check(h3eChildrenSize(index.bits, res, &count))
        return count
    }

    /// Returns descendants, with an explicit allocation limit. Increase the limit
    /// deliberately if your workload needs more than one million cells.
    public static func children(of index: H3ExtendedIndex, resolution: Int, maximumCount: Int = 1_000_000) throws -> [H3ExtendedIndex] {
        let count = try childrenCount(of: index, resolution: resolution)
        let size = try checkedSize(count, maximumCount: maximumCount)
        var out = Array(repeating: nullIndex.bits, count: size)
        try check(h3eChildren(index.bits, Int32(resolution), &out, count))
        return out.map(H3ExtendedIndex.init)
    }

    public static func gridDisk(origin: H3ExtendedIndex, k: Int, maximumCount: Int = 1_000_000) throws -> [H3ExtendedIndex] {
        try gridDiskDistances(origin: origin, k: k, maximumCount: maximumCount).map(\.index)
    }

    public static func gridDiskDistances(origin: H3ExtendedIndex, k: Int, maximumCount: Int = 1_000_000) throws -> [H3ExtendedGridDiskEntry] {
        guard let radius = Int32(exactly: k), radius >= 0 else { throw H3LibraryError(rawValue: E_DOMAIN.rawValue) }
        guard isValidCell(origin) else { throw H3LibraryError(rawValue: E_CELL_INVALID.rawValue) }
        var count: Int64 = 0
        try check(h3eDiskSize(radius, &count))
        let size = try checkedSize(count, maximumCount: maximumCount)
        var out = Array(repeating: nullIndex.bits, count: size)
        var distances = Array(repeating: Int32(0), count: size)
        try check(h3eDisk(origin.bits, radius, &out, &distances, count))
        return zip(out, distances).compactMap { bits, distance in
            let index = H3ExtendedIndex(bits)
            return index == nullIndex ? nil : H3ExtendedGridDiskEntry(index: index, distance: Int(distance))
        }
    }

    public static func gridDistance(from origin: H3ExtendedIndex, to target: H3ExtendedIndex) throws -> Int {
        var out: Int64 = 0
        try check(h3eDistance(origin.bits, target.bits, &out))
        return Int(out)
    }

    public static func cellAreaKm2(_ index: H3ExtendedIndex) throws -> Double {
        var area = 0.0
        try check(h3eAreaKm2(index.bits, &area))
        return area
    }

    public static func cellAreaM2(_ index: H3ExtendedIndex) throws -> Double {
        try cellAreaKm2(index) * 1_000_000
    }

    /// Lossless conversion from a valid standard H3 cell at resolution 0...15.
    public static func index(fromStandard index: H3Index) throws -> H3ExtendedIndex {
        var out = nullIndex.bits
        try check(h3eFromStandard(index, &out))
        return H3ExtendedIndex(out)
    }

    /// Lossless conversion at resolutions 0...15. For a finer cell, first request
    /// a parent at resolution 15 or below; this method never silently truncates.
    public static func standardIndex(from index: H3ExtendedIndex) throws -> H3Index {
        var out: UInt64 = 0
        try check(h3eToStandard(index.bits, &out))
        return out
    }

    public static func string(from index: H3ExtendedIndex) throws -> String {
        var out = Array<CChar>(repeating: 0, count: 33)
        try check(h3eFormat(index.bits, &out, out.count))
        return "h3x1:" + String(cString: out)
    }

    public static func index(from string: String) throws -> H3ExtendedIndex {
        // Enforce the version marker and complete input consumption, including NULs.
        guard string.hasPrefix("h3x1:") else { throw H3LibraryError(rawValue: E_CELL_INVALID.rawValue) }
        let digits = string.dropFirst(5)
        guard !digits.isEmpty, digits.utf8.count <= 32,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { throw H3LibraryError(rawValue: E_CELL_INVALID.rawValue) }
        var out = nullIndex.bits
        try check(String(digits).withCString { h3eParse($0, &out) })
        return H3ExtendedIndex(out)
    }

    private static func check(_ error: UInt32) throws {
        if error != 0 { throw H3LibraryError(rawValue: error) }
    }

    private static func checkedResolution(_ resolution: Int) throws -> Int32 {
        guard resolutions.contains(resolution) else { throw H3LibraryError(rawValue: E_RES_DOMAIN.rawValue) }
        return Int32(resolution)
    }

    private static func checkedSize(_ count: Int64, maximumCount: Int) throws -> Int {
        guard count > 0, let size = Int(exactly: count), size <= maximumCount,
              size <= Int.max / MemoryLayout<H3ExtendedBits>.stride
        else { throw H3LibraryError(rawValue: E_MEMORY_BOUNDS.rawValue) }
        return size
    }
}
