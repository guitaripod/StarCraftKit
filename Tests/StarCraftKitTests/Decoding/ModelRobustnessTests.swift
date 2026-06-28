import XCTest
@testable import StarCraftKit

/// Regression tests for defensive decoding: a single null/absent field in any list
/// element must never abort the whole array decode (the #1 class of live-usage bug).
final class ModelRobustnessTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .pandaScore
        return decoder
    }

    func testSeriesArrayWithNullsDecodes() throws {
        let json = """
        [
          {"id": 1, "name": null, "slug": null, "full_name": null, "league_id": null, "modified_at": null, "begin_at": null},
          {"id": 2, "name": "WCS", "slug": "wcs", "full_name": "WCS 2026", "league_id": 7, "year": 2026}
        ]
        """.data(using: .utf8)!
        let series = try decoder().decode([Series].self, from: json)
        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series[0].name, "Series 1")
        XCTAssertEqual(series[0].slug, "series-1")
        XCTAssertEqual(series[0].fullName, "Series 1")
        XCTAssertNil(series[0].modifiedAt)
        XCTAssertEqual(series[1].fullName, "WCS 2026")
    }

    func testTournamentArrayWithNullsDecodes() throws {
        let json = """
        [
          {"id": 10, "name": null, "slug": null, "serie_id": null, "league_id": null, "live_supported": null, "has_bracket": null, "modified_at": null},
          {"id": 11, "name": "GSL", "slug": "gsl", "serie_id": 3, "league_id": 2, "tier": "a"}
        ]
        """.data(using: .utf8)!
        let tournaments = try decoder().decode([Tournament].self, from: json)
        XCTAssertEqual(tournaments.count, 2)
        XCTAssertEqual(tournaments[0].name, "Tournament 10")
        XCTAssertEqual(tournaments[0].serieID, 0)
        XCTAssertNil(tournaments[0].liveSupported)
        XCTAssertEqual(tournaments[1].tier, "a")
    }

    func testLeagueArrayWithNullsDecodes() throws {
        let json = """
        [
          {"id": 5, "name": null, "slug": null, "image_url": "not a url with spaces", "modified_at": null},
          {"id": 6, "name": "ESL", "slug": "esl"}
        ]
        """.data(using: .utf8)!
        let leagues = try decoder().decode([League].self, from: json)
        XCTAssertEqual(leagues.count, 2)
        XCTAssertEqual(leagues[0].name, "League 5")
        XCTAssertEqual(leagues[0].slug, "league-5")
        XCTAssertEqual(leagues[1].name, "ESL")
    }

    func testPlayerArrayWithNullsAndBadNestedDecodes() throws {
        let json = """
        [
          {"id": 100, "name": null, "slug": null, "current_team": {"id": "not-an-int"}, "birthday": null},
          {"id": 101, "name": "Serral", "slug": "serral", "nationality": "FI"}
        ]
        """.data(using: .utf8)!
        let players = try decoder().decode([Player].self, from: json)
        XCTAssertEqual(players.count, 2)
        XCTAssertEqual(players[0].name, "Unknown")
        XCTAssertNil(players[0].currentTeam)
        XCTAssertEqual(players[1].name, "Serral")
        XCTAssertEqual(players[1].nationality, "FI")
    }

    func testTeamArrayWithNullsDecodes() throws {
        let json = """
        [
          {"id": 200, "name": null, "slug": null, "players": [{"id": "bad"}], "modified_at": null},
          {"id": 201, "name": "Team Liquid", "slug": "team-liquid", "acronym": "TL"}
        ]
        """.data(using: .utf8)!
        let teams = try decoder().decode([Team].self, from: json)
        XCTAssertEqual(teams.count, 2)
        XCTAssertEqual(teams[0].name, "Unknown")
        XCTAssertEqual(teams[1].displayName, "TL")
    }
}

/// Regression tests for case-insensitive pagination header parsing (Linux casing).
final class PaginationHeaderCaseTests: XCTestCase {
    func testLowercaseHeadersParse() {
        let info = PaginationInfo(from: ["x-page": "2", "x-per-page": "50", "x-total": "137"])
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.page, 2)
        XCTAssertEqual(info?.perPage, 50)
        XCTAssertEqual(info?.total, 137)
        XCTAssertEqual(info?.totalPages, 3)
        XCTAssertTrue(info?.hasNextPage ?? false)
    }

    func testTitleCaseHeadersParse() {
        let info = PaginationInfo(from: ["X-Page": "1", "X-Per-Page": "50", "X-Total": "10"])
        XCTAssertEqual(info?.page, 1)
        XCTAssertEqual(info?.totalPages, 1)
        XCTAssertFalse(info?.hasNextPage ?? true)
    }

    func testZeroPerPageRejected() {
        XCTAssertNil(PaginationInfo(from: ["x-page": "1", "x-per-page": "0", "x-total": "10"]))
    }
}
