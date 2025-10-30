import XCTest
@testable import H3

final class H3WrapperTests: XCTestCase {
    func testStringRoundTrip() throws {
        let origin = GeoCoord(latitude: 37.775938728915946, longitude: -122.41795063018799)
        let resolution = 9

        let index = try H3.index(from: origin, resolution: resolution)
        let string = try H3.string(from: index)
        let parsed = try H3.index(from: string)

        XCTAssertEqual(parsed, index)

        let center = try H3.coordinate(for: index)
        XCTAssertLessThan(abs(center.latitude - origin.latitude), 0.01)
        XCTAssertLessThan(abs(center.longitude - origin.longitude), 0.01)
        XCTAssertEqual(H3.resolution(of: index), resolution)
    }

    func testGridDiskContainsOrigin() throws {
        let origin = GeoCoord(latitude: 37.775938728915946, longitude: -122.41795063018799)
        let index = try H3.index(from: origin, resolution: 7)
        let neighbors = try H3.gridDisk(origin: index, k: 1)

        XCTAssertTrue(neighbors.contains(index))
        XCTAssertFalse(neighbors.isEmpty)
    }

    func testGridDistance() throws {
        let coordA = GeoCoord(latitude: 37.775938728915946, longitude: -122.41795063018799)
        let coordB = GeoCoord(latitude: 37.776, longitude: -122.412)
        let res = 8

        let indexA = try H3.index(from: coordA, resolution: res)
        let indexB = try H3.index(from: coordB, resolution: res)

        let distance = try H3.gridDistance(from: indexA, to: indexB)
        XCTAssertGreaterThanOrEqual(distance, 0)
    }
}
