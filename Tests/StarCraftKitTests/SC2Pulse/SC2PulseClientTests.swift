import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import StarCraftKit

/// Drives ``SC2PulseClient`` end-to-end through ``MockURLProtocol``: each request is
/// answered from a captured fixture, and the outgoing request URL / headers are asserted.
final class SC2PulseClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - searchCharacters

    func testSearchCharactersReturnsFixture() async throws {
        let body = try Fixtures.data("sc2pulse_characters")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, body) }

        let client = AggregationMocks.makePulseClient(userAgent: "StarCraftKitTests/UA")
        let characters = try await client.searchCharacters("Maru")

        XCTAssertEqual(characters.count, 2)
        XCTAssertEqual(characters.first?.displayName, "Maru")

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let url = try XCTUnwrap(request.url)
        XCTAssertTrue(url.path.hasSuffix("/api/characters"), "path was \(url.path)")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []
        XCTAssertTrue(
            queryItems.contains(URLQueryItem(name: "query", value: "Maru")),
            "query items were \(queryItems)"
        )

        let userAgent = request.value(forHTTPHeaderField: "User-Agent")
        XCTAssertEqual(userAgent, "StarCraftKitTests/UA")
    }

    // MARK: - topLadder

    func testTopLadderServesLadderFixtureAndBuildsQuery() async throws {
        let body = try Fixtures.data("sc2pulse_ladder")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, body) }

        let client = AggregationMocks.makePulseClient()
        let teams = try await client.topLadder(region: .eu)

        XCTAssertEqual(teams.count, 3)
        XCTAssertEqual(teams.first?.name, "Krystianer")

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let url = try XCTUnwrap(request.url)
        XCTAssertTrue(url.path.hasSuffix("/api/teams"), "path was \(url.path)")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "queue", value: "LOTV_1V1")), "\(items)")
        XCTAssertTrue(items.contains(URLQueryItem(name: "league", value: "GRANDMASTER")), "\(items)")
        XCTAssertTrue(items.contains(URLQueryItem(name: "region", value: "EU")), "\(items)")
        // `recent` is sent as a present (empty-valued) flag.
        XCTAssertTrue(items.contains { $0.name == "recent" }, "\(items)")
    }

    func testTopLadderRaceFilterAddsRaceQuery() async throws {
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, Data("[]".utf8)) }

        let client = AggregationMocks.makePulseClient()
        _ = try await client.topLadder(region: .kr, race: .zerg)

        let url = try XCTUnwrap(MockURLProtocol.capturedRequests.first?.url)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertTrue(items.contains(URLQueryItem(name: "race", value: "ZERG")), "\(items)")
    }

    // MARK: - liveStreams

    func testLiveStreamsUnwrapsStreamsFixture() async throws {
        let body = try Fixtures.data("sc2pulse_streams")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, body) }

        let client = AggregationMocks.makePulseClient()
        let streams = try await client.liveStreams()

        XCTAssertEqual(streams.count, 3)
        XCTAssertEqual(streams.first?.stream.userName, "Wintergaming")

        let url = try XCTUnwrap(MockURLProtocol.capturedRequests.first?.url)
        XCTAssertTrue(url.path.hasSuffix("/api/streams"), "path was \(url.path)")
    }

    // MARK: - seasons

    func testSeasonsReturnsFixture() async throws {
        let body = try Fixtures.data("sc2pulse_seasons")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, body) }

        let client = AggregationMocks.makePulseClient()
        let seasons = try await client.seasons()

        XCTAssertEqual(seasons.count, 6)
        XCTAssertEqual(seasons.first?.id, 143822)

        let url = try XCTUnwrap(MockURLProtocol.capturedRequests.first?.url)
        XCTAssertTrue(url.path.hasSuffix("/api/seasons"), "path was \(url.path)")
    }

    // MARK: - Lenient decode through the live client

    func testSearchCharactersDropsMalformedRowWithoutThrowing() async throws {
        let body = Data("""
        [
          {
            "currentStats": { "rating": 5500, "rank": 3 },
            "members": {
              "terranGamesPlayed": 50,
              "character": { "id": 1, "tag": "Keeps", "region": "EU" }
            }
          },
          { "members": 12345 }
        ]
        """.utf8)
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, body) }

        let client = AggregationMocks.makePulseClient()
        let characters = try await client.searchCharacters("Keeps")
        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.first?.name, "Keeps")
    }
}
