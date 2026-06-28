import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import StarCraftKit

/// Exercises the unified ``StarCraft`` facade composites with mock-wired source clients,
/// routing the shared mock handler by request host so multiple sources can be composed.
final class StarCraftFacadeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - availableSources

    func testAvailableSourcesReflectsConfiguredClients() {
        let pulseOnly = StarCraft(pulse: AggregationMocks.makePulseClient())
        XCTAssertEqual(pulseOnly.availableSources, [.sc2Pulse])

        let full = StarCraft(
            pulse: AggregationMocks.makePulseClient(),
            pandaScore: AggregationMocks.makePandaScoreClient(),
            aligulac: AggregationMocks.makeAligulacClient(),
            blizzard: AggregationMocks.makeBlizzardClient()
        )
        XCTAssertEqual(full.availableSources, [.sc2Pulse, .pandaScore, .aligulac, .blizzard])
    }

    // MARK: - profile (pulse only)

    func testProfilePulseOnly() async throws {
        let characters = try Fixtures.data("sc2pulse_characters")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, characters) }

        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        let profile = try await sc.profile(of: "Maru")

        XCTAssertNotNil(profile.ladder)
        XCTAssertNotNil(profile.mmr)
        XCTAssertEqual(profile.displayName, "Maru")
        XCTAssertNil(profile.rating, "No Aligulac source configured")
        XCTAssertNil(profile.proPlayer, "No PandaScore source configured")
        XCTAssertEqual(sc.availableSources, [.sc2Pulse])
        XCTAssertTrue(profile.contributingSources.contains(.sc2Pulse))
        XCTAssertFalse(profile.contributingSources.contains(.aligulac))
        XCTAssertFalse(profile.contributingSources.contains(.pandaScore))
    }

    // MARK: - profile (pulse + aligulac, multi-source aggregation)

    func testProfileAggregatesAligulacRating() async throws {
        // Pulse character that exposes a linked aligulacId so the facade resolves a rating
        // directly (no Aligulac player search needed).
        let pulseCharacters = Data("""
        [{
          "currentStats": { "rating": 6800, "rank": 1 },
          "members": {
            "zergGamesPlayed": 900,
            "character": { "id": 485, "tag": "Serral", "region": "EU" },
            "proNickname": "Serral",
            "proPlayer": {
              "proPlayer": { "id": 1, "aligulacId": 485, "nickname": "Serral" },
              "links": []
            }
          }
        }]
        """.utf8)
        let ratingBody = try Fixtures.data("aligulac_rating")

        MockURLProtocol.setHandler { request in
            let host = request.url?.host ?? ""
            if host == AggregationMocks.Host.aligulac {
                return AggregationMocks.ok(request, ratingBody)
            }
            return AggregationMocks.ok(request, pulseCharacters)
        }

        let sc = StarCraft(
            pulse: AggregationMocks.makePulseClient(),
            aligulac: AggregationMocks.makeAligulacClient()
        )
        let profile = try await sc.profile(of: "Serral")

        XCTAssertEqual(profile.aligulacId, 485)
        XCTAssertNotNil(profile.ladder)
        let rating = try XCTUnwrap(profile.rating, "Aligulac rating should be aggregated in")
        XCTAssertEqual(rating.rating, 1.85)
        XCTAssertTrue(profile.contributingSources.contains(.sc2Pulse))
        XCTAssertTrue(profile.contributingSources.contains(.aligulac))
        XCTAssertNil(profile.proPlayer)
    }

    // MARK: - liveScene (pulse only)

    func testLiveScenePulseOnlyDegradesGracefully() async throws {
        let streams = try Fixtures.data("sc2pulse_streams")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, streams) }

        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        let scene = try await sc.liveScene()

        XCTAssertEqual(scene.liveStreams.count, 3)
        XCTAssertTrue(scene.liveMatches.isEmpty, "No PandaScore source → no live matches")
        XCTAssertTrue(scene.runningTournaments.isEmpty)
        XCTAssertGreaterThan(scene.totalViewers, 0)
        XCTAssertEqual(scene.totalViewers, 773 + 624 + 606)
        XCTAssertTrue(scene.isActive)
    }

    // MARK: - topLadder

    func testTopLadderReturnsSnapshot() async throws {
        let ladder = try Fixtures.data("sc2pulse_ladder")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, ladder) }

        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        let snapshot = try await sc.topLadder(region: .eu)

        XCTAssertEqual(snapshot.region, .eu)
        XCTAssertEqual(snapshot.league, .grandmaster)
        XCTAssertEqual(snapshot.queue, .lotv1v1)
        XCTAssertEqual(snapshot.teams.count, 3)
        XCTAssertEqual(snapshot.teams.first?.name, "Krystianer")
    }

    func testSeasonsPassThrough() async throws {
        let seasons = try Fixtures.data("sc2pulse_seasons")
        MockURLProtocol.setHandler { request in AggregationMocks.ok(request, seasons) }

        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        let result = try await sc.seasons()
        XCTAssertEqual(result.count, 6)
    }

    // MARK: - Graceful errors for unconfigured sources

    func testLiveMatchesThrowsWhenNoPandaScore() async throws {
        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        await assertThrowsInvalidRequest { _ = try await sc.liveMatches() }
    }

    func testUpcomingMatchesThrowsWhenNoPandaScore() async throws {
        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        await assertThrowsInvalidRequest { _ = try await sc.upcomingMatches() }
    }

    func testTournamentsThrowsWhenNoPandaScore() async throws {
        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        await assertThrowsInvalidRequest { _ = try await sc.tournaments() }
    }

    func testOfficialLadderThrowsWhenNoBlizzard() async throws {
        let sc = StarCraft(pulse: AggregationMocks.makePulseClient())
        await assertThrowsInvalidRequest { _ = try await sc.officialLadder(region: .eu) }
    }

    // MARK: - Helpers

    private func assertThrowsInvalidRequest(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected APIError.invalidRequest", file: file, line: line)
        } catch let error as APIError {
            guard case .invalidRequest = error else {
                return XCTFail("expected .invalidRequest, got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("expected APIError, got \(error)", file: file, line: line)
        }
    }
}
