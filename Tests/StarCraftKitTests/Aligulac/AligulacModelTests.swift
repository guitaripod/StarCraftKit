import XCTest
@testable import StarCraftKit

/// Decoding + helper tests for the Aligulac models and client utilities. The Aligulac
/// client decodes with a plain `JSONDecoder`, so these fixtures use that.
final class AligulacModelTests: XCTestCase {
    private func decoder() -> JSONDecoder { JSONDecoder() }

    func testPlayerPageDecodes() throws {
        let data = try Fixtures.data("aligulac_player")
        let page = try decoder().decode(AligulacPage<AligulacPlayer>.self, from: data)

        XCTAssertEqual(page.meta.totalCount, 1)
        let player = try XCTUnwrap(page.objects.first)
        XCTAssertEqual(player.id, 485)
        XCTAssertEqual(player.tag, "Serral")
        XCTAssertEqual(player.name, "Joona Sotala")
        XCTAssertEqual(player.country, "FI")
        XCTAssertEqual(player.race, .zerg)
        XCTAssertEqual(player.currentRating, "/api/v1/rating/1234567/")
    }

    func testRatingMapsRaceMatchupKeys() throws {
        let data = try Fixtures.data("aligulac_rating")
        let page = try decoder().decode(AligulacPage<AligulacRating>.self, from: data)
        let rating = try XCTUnwrap(page.objects.first)

        XCTAssertEqual(rating.id, 9876543)
        XCTAssertEqual(rating.rating, 1.85)
        XCTAssertEqual(rating.ratingVsProtoss, 1.92) // rating_vp
        XCTAssertEqual(rating.ratingVsTerran, 1.74)  // rating_vt
        XCTAssertEqual(rating.ratingVsZerg, 1.66)    // rating_vz
        XCTAssertEqual(rating.dev, 0.31)
        XCTAssertEqual(rating.position, 1)
        XCTAssertEqual(rating.decay, 0)
        XCTAssertTrue(rating.isActive)
    }

    func testRatingIsActiveThreshold() throws {
        let data = try Fixtures.data("aligulac_rating")
        let rating = try decoder().decode(AligulacPage<AligulacRating>.self, from: data).objects.first
        XCTAssertEqual(rating?.isActive, true)
    }

    func testMatchListDecodes() throws {
        let data = try Fixtures.data("aligulac_matches")
        let page = try decoder().decode(AligulacPage<AligulacMatch>.self, from: data)

        XCTAssertEqual(page.objects.count, 3)
        let first = try XCTUnwrap(page.objects.first)
        XCTAssertEqual(first.id, 111)
        XCTAssertEqual(first.playerA, "/api/v1/player/485/") // pla
        XCTAssertEqual(first.playerB, "/api/v1/player/26/")  // plb
        XCTAssertEqual(first.scoreA, 3) // sca
        XCTAssertEqual(first.scoreB, 1) // scb
        XCTAssertEqual(first.raceA, .zerg)  // rca
        XCTAssertEqual(first.raceB, .terran) // rcb
        XCTAssertEqual(first.event, "IEM Katowice 2026 - Final")
    }

    // MARK: - resourceID

    func testResourceIDExtractsTrailingNumber() {
        XCTAssertEqual(AligulacClient.resourceID("/api/v1/player/123/"), 123)
        XCTAssertEqual(AligulacClient.resourceID("/api/v1/player/485/"), 485)
        XCTAssertEqual(AligulacClient.resourceID("/api/v1/rating/9876543/"), 9876543)
    }

    func testResourceIDNilForBadInput() {
        XCTAssertNil(AligulacClient.resourceID(nil))
        XCTAssertNil(AligulacClient.resourceID("/api/v1/player/"))
        XCTAssertNil(AligulacClient.resourceID(""))
    }

    // MARK: - HeadToHead.winRateA

    func testWinRateA() {
        let h2h = HeadToHead(playerAID: 1, playerBID: 2, winsA: 3, winsB: 1, matches: [])
        XCTAssertEqual(try XCTUnwrap(h2h.winRateA), 0.75, accuracy: 0.0001)

        let even = HeadToHead(playerAID: 1, playerBID: 2, winsA: 5, winsB: 5, matches: [])
        XCTAssertEqual(try XCTUnwrap(even.winRateA), 0.5, accuracy: 0.0001)
    }

    func testWinRateANilWhenNoGames() {
        let h2h = HeadToHead(playerAID: 1, playerBID: 2, winsA: 0, winsB: 0, matches: [])
        XCTAssertNil(h2h.winRateA)
    }
}
