import XCTest
@testable import StarCraftKit

final class StarCraftKitTests: XCTestCase {
    func testVersion() throws {
        XCTAssertEqual(StarCraftKitInfo.version, "2.0.0")
    }

    func testMinimumSwiftVersion() throws {
        XCTAssertEqual(StarCraftKitInfo.minimumSwiftVersion, "6.0")
    }
}
