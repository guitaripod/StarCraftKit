import Foundation
import XCTest
@testable import StarCraftKit

/// Loads JSON fixtures bundled into the test target's resources.
enum Fixtures {
    /// Raw bytes of a bundled `<name>.json` resource.
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            XCTFail("Missing fixture: \(name).json", file: file, line: line)
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    /// A decoder configured exactly like ``StarCraftClient``'s (PandaScore date strategy).
    static func pandaScoreDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .pandaScore
        return decoder
    }

    enum FixtureError: Error { case missing(String) }
}
