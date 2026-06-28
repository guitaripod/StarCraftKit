import XCTest
@testable import StarCraftKit

/// Regression tests for the decoding overhaul: matches must decode even when the API
/// sends `null` for fields the old models declared non-optional, and timestamps may
/// carry fractional seconds. These lock in the #1 bug that the modernization fixed.
final class MatchDecodingTests: XCTestCase {
    private func decoder() -> JSONDecoder { Fixtures.pandaScoreDecoder() }

    func testNormalMatchArrayDecodes() throws {
        let data = try Fixtures.data("matches")
        let matches = try decoder().decode([Match].self, from: data)

        XCTAssertEqual(matches.count, 1)
        let match = try XCTUnwrap(matches.first)
        XCTAssertEqual(match.id, 1001)
        XCTAssertEqual(match.name, "Serral vs Maru")
        XCTAssertEqual(match.slug, "serral-vs-maru")
        XCTAssertEqual(match.status, .finished)
        XCTAssertEqual(match.tournamentID, 500)
        XCTAssertEqual(match.serieID, 300)
        XCTAssertEqual(match.leagueID, 200)
        XCTAssertEqual(match.numberOfGames, 5)
        XCTAssertEqual(match.games.count, 3)
        XCTAssertEqual(match.opponents.count, 2)
        XCTAssertEqual(match.results.count, 2)
        XCTAssertNotNil(match.beginAt)
        XCTAssertNotNil(match.endAt)
        XCTAssertNotNil(match.modifiedAt)
        XCTAssertEqual(match.winner?.id, 7001)
        XCTAssertEqual(match.streams?.first?.rawURL?.absoluteString, "https://twitch.tv/example")
        XCTAssertEqual(match.duration, 90 * 60)
    }

    func testMatchArrayWithNullsDecodesWithoutThrowing() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)

        XCTAssertEqual(matches.count, 2)
    }

    func testNullNameFallsBackToOpponents() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)
        let match = try XCTUnwrap(matches.first { $0.id == 2001 })

        XCTAssertFalse(match.name.isEmpty, "null name must fall back to a non-empty value")
        XCTAssertEqual(match.name, "Clem vs Reynor")
        XCTAssertFalse(match.slug.isEmpty)
    }

    func testNullNameWithSlugButNoOpponents() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)
        let match = try XCTUnwrap(matches.first { $0.id == 2002 })

        XCTAssertFalse(match.name.isEmpty)
        XCTAssertEqual(match.name, "lone-match")
    }

    func testMissingNumberOfGamesDefaultsToAtLeastOne() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)

        for match in matches {
            XCTAssertGreaterThanOrEqual(match.numberOfGames, 1, "match \(match.id) must report >= 1 game")
        }
    }

    func testNullDatesDecodeAsNil() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)
        let match = try XCTUnwrap(matches.first { $0.id == 2001 })

        XCTAssertNil(match.beginAt)
        XCTAssertNil(match.endAt)
        XCTAssertNil(match.modifiedAt)
        XCTAssertNil(match.leagueID)
    }

    func testNullStreamRawURLDecodes() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)
        let match = try XCTUnwrap(matches.first { $0.id == 2001 })
        let stream = try XCTUnwrap(match.streams?.first)

        XCTAssertNil(stream.rawURL)
        XCTAssertNil(stream.embedURL)
        XCTAssertEqual(stream.language, "en")
    }

    func testNullOpponentSlugDecodes() throws {
        let data = try Fixtures.data("matches_with_nulls")
        let matches = try decoder().decode([Match].self, from: data)
        let match = try XCTUnwrap(matches.first { $0.id == 2001 })
        let opponent = try XCTUnwrap(match.opponents.first)

        XCTAssertNil(opponent.opponent.slug)
        XCTAssertEqual(opponent.opponent.name, "Clem")
    }

    func testFractionalSecondsDateParses() throws {
        let data = try Fixtures.data("match_fractional_date")
        let match = try decoder().decode(Match.self, from: data)

        let begin = try XCTUnwrap(match.beginAt)
        let end = try XCTUnwrap(match.endAt)
        XCTAssertNotNil(match.modifiedAt)

        let expectedBegin = ISO8601DateFormatter.pandaScoreFractional.date(from: "2026-01-15T18:00:00.123Z")
        XCTAssertEqual(begin.timeIntervalSince1970, try XCTUnwrap(expectedBegin).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertGreaterThan(end, begin)
        XCTAssertEqual(match.numberOfGames, 7)
    }
}
