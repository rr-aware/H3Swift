import XCTest
import H3Extended

final class H3ExtendedTests: XCTestCase {
    private let tokyo = GeoCoord(latitude: 35.681236, longitude: 139.767125)

    func testAllTwentyResolutionsAndStandardCompatibility() throws {
        let points = [tokyo, GeoCoord(latitude: 0, longitude: 0),
                      GeoCoord(latitude: 89.999, longitude: 179.999),
                      GeoCoord(latitude: -89.999, longitude: -179.999),
                      GeoCoord(latitude: 0, longitude: 180)]
        for point in points {
            for res in 0...19 {
                let index = try H3Extended.index(from: point, resolution: res)
                XCTAssertTrue(H3Extended.isValidCell(index))
                XCTAssertEqual(H3Extended.resolution(of: index), res)
                let center = try H3Extended.coordinate(for: index)
                XCTAssertEqual(try H3Extended.index(from: center, resolution: res), index)
                let boundary = try H3Extended.boundary(for: index)
                XCTAssertTrue((5...10).contains(boundary.vertices.count))
                XCTAssertTrue(boundary.vertices.allSatisfy { $0.latitude.isFinite && $0.longitude.isFinite })
                let area = try H3Extended.cellAreaM2(index)
                XCTAssertTrue(area.isFinite && area > 0)
                if res <= 15 {
                    let standard = try H3.index(from: point, resolution: res)
                    XCTAssertEqual(try H3Extended.index(fromStandard: standard), index)
                    XCTAssertEqual(try H3Extended.standardIndex(from: index), standard)
                    XCTAssertEqual(try H3.coordinate(for: standard), center)
                    XCTAssertEqual(try H3.boundary(for: standard), boundary)
                    XCTAssertEqual(try H3.cellAreaM2(standard), area, accuracy: area * 1e-12)
                }
            }
        }
        XCTAssertEqual(try H3.string(from: H3.index(from: GeoCoord(latitude: 37.775938728915946, longitude: -122.41795063018799), resolution: 9)), "8928308280fffff")
    }

    func testNewLevelsHaveDistinctChildrenAndNeighbors() throws {
        for res in 15...18 {
            let parent = try H3Extended.index(from: tokyo, resolution: res)
            let children = try H3Extended.children(of: parent, resolution: res + 1)
            XCTAssertEqual(children.count, 7)
            XCTAssertEqual(Set(children).count, 7)
            for child in children {
                XCTAssertTrue(H3Extended.isValidCell(child))
                XCTAssertEqual(try H3Extended.parent(of: child, resolution: res), parent)
                XCTAssertEqual(try H3Extended.index(from: H3Extended.coordinate(for: child), resolution: res + 1), child)
                let disk = try H3Extended.gridDiskDistances(origin: child, k: 2)
                XCTAssertEqual(disk.count, 19)
                XCTAssertEqual(Set(disk.map(\.index)).count, 19)
                for entry in disk {
                    XCTAssertEqual(try H3Extended.gridDistance(from: child, to: entry.index), entry.distance)
                }
            }
        }
        let parent = try H3Extended.index(from: tokyo, resolution: 15)
        let descendants = try H3Extended.children(of: parent, resolution: 19)
        XCTAssertEqual(descendants.count, 2401)
        XCTAssertEqual(Set(descendants).count, 2401)
        for child in descendants {
            XCTAssertEqual(try H3Extended.parent(of: child, resolution: 15), parent)
        }
    }

    func testAllPentagonsAtExtendedResolutions() throws {
        var standardPentagons = Array<UInt64>(repeating: 0, count: 12)
        XCTAssertEqual(getPentagons(15, &standardPentagons), 0)
        for standard in standardPentagons {
            var pentagon = try H3Extended.index(fromStandard: standard)
            for res in 16...19 {
                let children = try H3Extended.children(of: pentagon, resolution: res)
                XCTAssertEqual(children.count, 6)
                XCTAssertEqual(Set(children).count, 6)
                for child in children {
                    XCTAssertTrue(H3Extended.isValidCell(child))
                    XCTAssertEqual(try H3Extended.parent(of: child, resolution: res - 1), pentagon)
                    XCTAssertEqual(try H3Extended.index(from: H3Extended.coordinate(for: child), resolution: res), child)
                    XCTAssertGreaterThan(try H3Extended.cellAreaM2(child), 0)
                    XCTAssertTrue((5...10).contains(try H3Extended.boundary(for: child).vertices.count))
                }
                pentagon = try XCTUnwrap(children.first { H3Extended.isPentagon($0) })
                let disk = try H3Extended.gridDisk(origin: pentagon, k: 1)
                XCTAssertEqual(disk.count, 6)
                XCTAssertEqual(Set(disk).count, 6)
                XCTAssertTrue(disk.allSatisfy(H3Extended.isValidCell))
            }
        }
    }

    func testWorldwideCentersAtNewResolutions() throws {
        // Deterministic global coverage, including both poles and antimeridian.
        for lat in stride(from: -90, through: 90, by: 9) {
            for lng in stride(from: -180, through: 180, by: 13) {
                for res in 16...19 {
                    let index = try H3Extended.index(from: GeoCoord(latitude: Double(lat), longitude: Double(lng)), resolution: res)
                    let center = try H3Extended.coordinate(for: index)
                    XCTAssertEqual(try H3Extended.index(from: center, resolution: res), index, "\(lat), \(lng), res \(res)")
                    XCTAssertGreaterThan(try H3Extended.cellAreaM2(index), 0)
                    let disk = try H3Extended.gridDisk(origin: index, k: 1)
                    XCTAssertEqual(Set(disk).count, 7)
                    for neighbor in disk {
                        XCTAssertTrue(H3Extended.isValidCell(neighbor))
                    }
                }
            }
        }
    }

    func testFaceCentersAndFineCellScale() throws {
        var roots = Array<UInt64>(repeating: 0, count: 122)
        XCTAssertEqual(getRes0Cells(&roots), 0)
        for root in roots {
            let center = try H3.coordinate(for: root)
            for res in 16...19 {
                let index = try H3Extended.index(from: center, resolution: res)
                let disk = try H3Extended.gridDisk(origin: index, k: 2)
                for cell in disk {
                    let point = try H3Extended.coordinate(for: cell)
                    XCTAssertEqual(try H3Extended.index(from: point, resolution: res), cell)
                    XCTAssertGreaterThan(try H3Extended.cellAreaM2(cell), 0)
                }
            }
        }
        let index = try H3Extended.index(from: tokyo, resolution: 19)
        let center = try H3Extended.coordinate(for: index)
        let boundary = try H3Extended.boundary(for: index)
        for vertex in boundary.vertices {
            let meters = H3.greatCircleDistanceKm(from: center, to: vertex) * 1000
            XCTAssertGreaterThan(meters, 0.005)
            XCTAssertLessThan(meters, 0.025)
        }
        let coarse = try H3Extended.index(from: tokyo, resolution: 15)
        let ratio = try H3Extended.cellAreaM2(coarse) / H3Extended.cellAreaM2(index)
        XCTAssertEqual(ratio, 2401, accuracy: 0.1)
    }

    func testVersionedSerializationAndInvalidInputs() throws {
        let index = try H3Extended.index(from: tokyo, resolution: 19)
        let string = try H3Extended.string(from: index)
        XCTAssertTrue(string.hasPrefix("h3x1:"))
        XCTAssertEqual(try H3Extended.index(from: string), index)
        let data = try JSONEncoder().encode(index)
        XCTAssertEqual(try JSONDecoder().decode(H3ExtendedIndex.self, from: data), index)
        for text in ["", "h3x1:", "h3x2:123", "8928308280fffff", "h3x1:0", string + "!", string + "\0", "h3x1:" + String(repeating: "f", count: 33)] {
            XCTAssertThrowsError(try H3Extended.index(from: text))
        }
        for res in [-1, 20, Int.min, Int.max] {
            XCTAssertThrowsError(try H3Extended.index(from: tokyo, resolution: res))
            XCTAssertThrowsError(try H3Extended.parent(of: index, resolution: res))
            XCTAssertThrowsError(try H3Extended.children(of: index, resolution: res))
        }
        XCTAssertThrowsError(try H3Extended.standardIndex(from: index))
        XCTAssertThrowsError(try H3Extended.index(fromStandard: 0))
        XCTAssertThrowsError(try H3Extended.coordinate(for: .init(high: .max, low: .max)))
        XCTAssertThrowsError(try H3Extended.boundary(for: .init(high: 0, low: 0)))
        XCTAssertThrowsError(try H3Extended.index(from: GeoCoord(latitude: .nan, longitude: 0), resolution: 19))
        XCTAssertThrowsError(try H3Extended.gridDisk(origin: index, k: Int.max))
        XCTAssertThrowsError(try H3Extended.gridDisk(origin: index, k: -1))
        XCTAssertThrowsError(try H3Extended.gridDisk(origin: index, k: 1000, maximumCount: 10))
        let root = try H3Extended.parent(of: index, resolution: 0)
        XCTAssertEqual(try H3Extended.childrenCount(of: root, resolution: 19), 11_398_895_185_373_143)
        XCTAssertThrowsError(try H3Extended.children(of: root, resolution: 19))
    }
}
