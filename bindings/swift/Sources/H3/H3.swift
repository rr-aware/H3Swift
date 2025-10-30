@_exported import CH3
import Foundation

public typealias H3Index = UInt64

/// Units describing how latitude/longitude values are provided.
public enum AngleUnit: Sendable {
    case degrees
    case radians
}

/// Swift representation of a geographic coordinate.
public struct GeoCoord: Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    /// Creates a coordinate from the supplied values.
    /// - Parameters:
    ///   - latitude: Latitude value.
    ///   - longitude: Longitude value.
    ///   - unit: Indicates whether the inputs are already in radians.
    public init(latitude: Double, longitude: Double, unit: AngleUnit = .degrees) {
        switch unit {
        case .degrees:
            self.latitude = latitude
            self.longitude = longitude
        case .radians:
            self.latitude = latitude.radiansToDegrees
            self.longitude = longitude.radiansToDegrees
        }
    }

    /// Underlying C LatLng representation (always in radians).
    var latLng: LatLng {
        LatLng(lat: latitude.degreesToRadians, lng: longitude.degreesToRadians)
    }

    /// Creates a coordinate from a C `LatLng` (provided in radians).
    init(latLng: LatLng) {
        self.latitude = latLng.lat.radiansToDegrees
        self.longitude = latLng.lng.radiansToDegrees
    }
}

/// Polygon boundary represented as a list of coordinates.
public struct GeoBoundary: Equatable, Hashable, Sendable {
    public var vertices: [GeoCoord]
}

/// Convenience wrapper for results that pair an index with a grid distance.
public struct GridDiskEntry: Equatable, Hashable, Sendable {
    public var index: H3Index
    public var distance: Int
}

/// Error type thrown when an H3 C API call fails.
public struct H3LibraryError: Swift.Error, CustomStringConvertible, Sendable {
    public let code: H3ErrorCodes?
    public let rawValue: CH3.H3Error

    public init(rawValue: CH3.H3Error) {
        self.rawValue = rawValue
        self.code = H3ErrorCodes(rawValue: rawValue)
    }

    public var description: String {
        guard let pointer = describeH3Error(rawValue) else {
            return "H3 error \(rawValue)"
        }
        return String(cString: pointer)
    }
}

/// High-level Swift interface for the H3 C library.
public enum H3 {
    /// Sentinel index used by the C library when no value is available.
    public static let nullIndex: H3Index = H3Index(H3_NULL)

    /// Returns the H3 index that contains the supplied coordinate.
    /// - Parameters:
    ///   - coordinate: Input coordinate (degrees by default).
    ///   - resolution: Target H3 resolution (0...15).
    public static func index(from coordinate: GeoCoord, resolution: Int) throws -> H3Index {
        var coord = coordinate.latLng
        var out: H3Index = 0
        try check(CH3.latLngToCell(&coord, Int32(resolution), &out))
        return out
    }

    /// Returns the geographic center of an H3 index.
    public static func coordinate(for index: H3Index) throws -> GeoCoord {
        var latLng = LatLng(lat: 0, lng: 0)
        try check(CH3.cellToLatLng(index, &latLng))
        return GeoCoord(latLng: latLng)
    }

    /// Returns the boundary polygon of an H3 index.
    public static func boundary(for index: H3Index) throws -> GeoBoundary {
        var boundary = zeroedBoundary
        try check(CH3.cellToBoundary(index, &boundary))
        let vertsMirror = Mirror(reflecting: boundary.verts)
        let coords = vertsMirror.children
            .compactMap { $0.value as? LatLng }
            .prefix(Int(boundary.numVerts))
            .map(GeoCoord.init(latLng:))
        return GeoBoundary(vertices: Array(coords))
    }

    /// Returns the grid distance (in k-rings) between two H3 indexes.
    public static func gridDistance(from origin: H3Index, to target: H3Index) throws -> Int {
        var distance: Int64 = 0
        try check(CH3.gridDistance(origin, target, &distance))
        return Int(distance)
    }

    /// Returns all cells within `k` of an origin cell.
    public static func gridDisk(origin: H3Index, k: Int) throws -> [H3Index] {
        let maxCount = Int(try maxGridDiskSizeValue(k: k))
        var results = Array(repeating: nullIndex, count: maxCount)
        try results.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            try check(CH3.gridDisk(origin, Int32(k), base))
        }
        return results.filter { $0 != nullIndex }
    }

    /// Returns cells and their distances within `k` of an origin cell.
    public static func gridDiskDistances(origin: H3Index, k: Int) throws -> [GridDiskEntry] {
        let maxCount = Int(try maxGridDiskSizeValue(k: k))
        var results = Array(repeating: nullIndex, count: maxCount)
        var distances = Array(repeating: Int32.max, count: maxCount)
        try results.withUnsafeMutableBufferPointer { resultBuffer in
            try distances.withUnsafeMutableBufferPointer { distanceBuffer in
                guard
                    let resultBase = resultBuffer.baseAddress,
                    let distanceBase = distanceBuffer.baseAddress
                else {
                    return
                }
                try check(CH3.gridDiskDistances(origin, Int32(k), resultBase, distanceBase))
            }
        }

        return zip(results, distances)
            .filter { $0.0 != nullIndex }
            .map { GridDiskEntry(index: $0.0, distance: Int($0.1)) }
    }

    /// Returns the parent index at a lower resolution.
    public static func parent(of index: H3Index, resolution: Int) throws -> H3Index {
        var parentIndex: H3Index = 0
        try check(CH3.cellToParent(index, Int32(resolution), &parentIndex))
        return parentIndex
    }

    /// Returns all direct children at the requested resolution.
    public static func children(of index: H3Index, resolution: Int) throws -> [H3Index] {
        var size: Int64 = 0
        try check(CH3.cellToChildrenSize(index, Int32(resolution), &size))
        var children = Array(repeating: nullIndex, count: Int(size))
        try children.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            try check(CH3.cellToChildren(index, Int32(resolution), base))
        }
        return children.filter { $0 != nullIndex }
    }

    /// Converts an H3 index to its canonical string representation.
    public static func string(from index: H3Index) throws -> String {
        var buffer = Array<CChar>(repeating: 0, count: h3StringLength)
        let error = buffer.withUnsafeMutableBufferPointer { ptr -> CH3.H3Error in
            guard let base = ptr.baseAddress else { return genericFailure }
            return CH3.h3ToString(index, base, ptr.count)
        }
        try check(error)
        return buffer.withUnsafeBufferPointer { bufferPtr in
            String(cString: bufferPtr.baseAddress!)
        }
    }

    /// Parses a canonical string into an H3 index.
    public static func index(from string: String) throws -> H3Index {
        var value: H3Index = 0
        let error = string.withCString { pointer -> CH3.H3Error in
            CH3.stringToH3(pointer, &value)
        }
        try check(error)
        return value
    }

    /// Returns whether the given index is a valid cell.
    public static func isValidCell(_ index: H3Index) -> Bool {
        CH3.isValidCell(index) != 0
    }

    /// Returns whether the given index is valid in any index mode.
    public static func isValidIndex(_ index: H3Index) -> Bool {
        CH3.isValidIndex(index) != 0
    }

    /// Returns the area of the cell in square kilometers.
    public static func cellAreaKm2(_ index: H3Index) throws -> Double {
        var value = 0.0
        try check(CH3.cellAreaKm2(index, &value))
        return value
    }

    /// Returns the area of the cell in square meters.
    public static func cellAreaM2(_ index: H3Index) throws -> Double {
        var value = 0.0
        try check(CH3.cellAreaM2(index, &value))
        return value
    }

    /// Returns the great-circle distance in kilometers between two coordinates.
    public static func greatCircleDistanceKm(from: GeoCoord, to: GeoCoord) -> Double {
        var a = from.latLng
        var b = to.latLng
        return CH3.greatCircleDistanceKm(&a, &b)
    }

    /// Returns the H3 resolution for an index.
    public static func resolution(of index: H3Index) -> Int {
        Int(CH3.getResolution(index))
    }
}

private extension H3 {
    static func check(_ result: CH3.H3Error) throws {
        guard result == CH3.H3Error(0) else {
            throw H3LibraryError(rawValue: result)
        }
    }

    static func maxGridDiskSizeValue(k: Int) throws -> Int64 {
        var size: Int64 = 0
        try check(CH3.maxGridDiskSize(Int32(k), &size))
        return size
    }

    static var zeroedBoundary: CellBoundary {
        let zero = LatLng(lat: 0, lng: 0)
        return CellBoundary(
            numVerts: 0,
            verts: (
                zero, zero, zero, zero, zero,
                zero, zero, zero, zero, zero
            )
        )
    }
}

private let h3StringLength = 17
private let genericFailure: CH3.H3Error = 1

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
    var radiansToDegrees: Double { self * 180.0 / .pi }
}
