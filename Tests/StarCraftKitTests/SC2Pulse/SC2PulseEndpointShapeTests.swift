import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StarCraftKit

/// Regression tests for SC2 Pulse endpoints whose real JSON is object-wrapped, not a
/// bare array — patches (`{patch,releases}` per row), character-matches (`{result:[...]}`),
/// and tier-thresholds (nested region→league→tier object). These previously threw or
/// returned all-nil records.
final class SC2PulseEndpointShapeTests: XCTestCase {
    private func makeClient(_ body: Data) -> SC2PulseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.respond(status: 200, body: body)
        return SC2PulseClient(configuration: .init(
            baseURL: URL(string: "https://pulse.mock.test/sc2/")!,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: config
        ))
    }

    private func fixture(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testPatchesUnwrapsNestedPatchObject() async throws {
        let data = fixture("sc2pulse_patches")
        let client = makeClient(data)
        let patches = try await client.patches()
        XCTAssertFalse(patches.isEmpty)
        XCTAssertEqual(patches.first?.version, "5.0.16")
        XCTAssertEqual(patches.first?.build, 97364)
    }

    func testRecentMatchesUnwrapsResultEnvelope() async throws {
        let data = fixture("sc2pulse_matches")
        let client = makeClient(data)
        let matches = try await client.recentMatches(characterId: 11298817, limit: 2)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertNotNil(matches.first?.match?.id)
    }

    func testTierThresholdsFlattensNestedObjectAndToleratesEmpty() async throws {
        let nested = #"{"EU":{"6":{"0":[5000,9999],"1":[4500,5000]}}}"#.data(using: .utf8)!
        let client = makeClient(nested)
        let tiers = try await client.tierThresholds(season: 143823, region: .eu)
        XCTAssertEqual(tiers.count, 2)
        XCTAssertTrue(tiers.contains { $0.minRating == 5000 && $0.maxRating == 9999 })

        let emptyClient = makeClient("{}".data(using: .utf8)!)
        let empty = try await emptyClient.tierThresholds(season: 143823, region: .eu)
        XCTAssertTrue(empty.isEmpty)
    }
}
