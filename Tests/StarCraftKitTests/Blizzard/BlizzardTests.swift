import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import StarCraftKit

/// Decode-tests the Blizzard models against small fixtures, then drives ``BlizzardClient``
/// through ``MockURLProtocol`` including the OAuth client-credentials token exchange.
final class BlizzardTests: XCTestCase {
    private let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Model decoding

    func testGrandmasterFixtureDecodes() throws {
        let data = try Fixtures.data("blizzard_grandmaster")
        let ladder = try decoder.decode(GrandmasterLadder.self, from: data)
        let team = try XCTUnwrap(ladder.ladderTeams?.first)

        XCTAssertEqual(team.mmr, 6500)
        XCTAssertEqual(team.wins, 50)
        XCTAssertEqual(team.losses, 40)
        XCTAssertEqual(team.joinTimestamp, 1700000000000)

        let member = try XCTUnwrap(team.primary)
        // id arrives as a String, not an Int.
        XCTAssertEqual(member.id, "123")
        XCTAssertEqual(member.displayName, "Player")
        XCTAssertEqual(member.clanTag, "ABC")
        XCTAssertEqual(team.name, "Player")
        XCTAssertEqual(team.race, .zerg)
        XCTAssertEqual(member.race, .zerg)

        let winRate = try XCTUnwrap(team.winRate)
        XCTAssertEqual(winRate, 50.0 / 90.0, accuracy: 1e-9)
    }

    func testSeasonFixtureDecodesEpochStringDates() throws {
        let data = try Fixtures.data("blizzard_season")
        let season = try decoder.decode(BlizzardSeason.self, from: data)

        XCTAssertEqual(season.seasonId, 53)
        XCTAssertEqual(season.number, 2)
        XCTAssertEqual(season.year, 2026)

        // Dates arrive as quoted epoch strings and must resolve to the right instant.
        let start = try XCTUnwrap(season.start)
        let end = try XCTUnwrap(season.end)
        XCTAssertEqual(start.timeIntervalSince1970, 1_704_412_800, accuracy: 0.5)
        XCTAssertEqual(end.timeIntervalSince1970, 1_712_188_800, accuracy: 0.5)
    }

    func testSeasonDateNilForNonNumericString() throws {
        let json = Data(#"{"seasonId":1,"startDate":"not-a-number","endDate":null}"#.utf8)
        let season = try decoder.decode(BlizzardSeason.self, from: json)
        XCTAssertNil(season.start)
        XCTAssertNil(season.end)
    }

    func testRegionIds() {
        XCTAssertEqual(BlizzardRegion.us.regionId, 1)
        XCTAssertEqual(BlizzardRegion.eu.regionId, 2)
        XCTAssertEqual(BlizzardRegion.kr.regionId, 3)
        XCTAssertEqual(BlizzardRegion.tw.regionId, 3)
    }

    // MARK: - Client (OAuth + API)

    func testGrandmasterLadderFlowExchangesTokenAndAuthorizesRequest() async throws {
        let gmBody = try Fixtures.data("blizzard_grandmaster")
        let tokenBody = Data(#"{"access_token":"t","token_type":"bearer","expires_in":86399}"#.utf8)

        MockURLProtocol.setHandler { request in
            let host = request.url?.host ?? ""
            if host == AggregationMocks.Host.blizzardOAuth {
                return AggregationMocks.ok(request, tokenBody)
            }
            return AggregationMocks.ok(request, gmBody)
        }

        let client = AggregationMocks.makeBlizzardClient()
        let ladder = try await client.grandmasterLadder(region: .eu)

        XCTAssertEqual(ladder.count, 1)
        XCTAssertEqual(ladder.first?.name, "Player")
        XCTAssertEqual(ladder.first?.mmr, 6500)

        let requests = MockURLProtocol.capturedRequests
        let tokenRequest = try XCTUnwrap(requests.first { $0.url?.host == AggregationMocks.Host.blizzardOAuth })
        let apiRequest = try XCTUnwrap(requests.first { $0.url?.host != AggregationMocks.Host.blizzardOAuth })

        // The token endpoint is POSTed with a Basic auth header derived from the credentials.
        XCTAssertEqual(tokenRequest.httpMethod, "POST")
        let basic = Data("client-id:client-secret".utf8).base64EncodedString()
        XCTAssertEqual(tokenRequest.value(forHTTPHeaderField: "Authorization"), "Basic \(basic)")

        // The API request carries the bearer token from the exchange.
        XCTAssertEqual(apiRequest.value(forHTTPHeaderField: "Authorization"), "Bearer t")
        let apiPath = try XCTUnwrap(apiRequest.url?.path)
        XCTAssertTrue(apiPath.hasSuffix("sc2/ladder/grandmaster/2"), "path was \(apiPath)")
    }

    func testCurrentSeasonFlow() async throws {
        let seasonBody = try Fixtures.data("blizzard_season")
        let tokenBody = Data(#"{"access_token":"abc","token_type":"bearer","expires_in":86399}"#.utf8)

        MockURLProtocol.setHandler { request in
            if request.url?.host == AggregationMocks.Host.blizzardOAuth {
                return AggregationMocks.ok(request, tokenBody)
            }
            return AggregationMocks.ok(request, seasonBody)
        }

        let client = AggregationMocks.makeBlizzardClient()
        let season = try await client.currentSeason(region: .eu)
        XCTAssertEqual(season.seasonId, 53)
        XCTAssertNotNil(season.start)
    }
}
