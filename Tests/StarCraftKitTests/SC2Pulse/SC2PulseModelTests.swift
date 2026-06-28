import Foundation
import XCTest
@testable import StarCraftKit

/// Decodes the real captured SC2 Pulse fixtures and validates the model surface
/// (computed `mmr`, `name`, `displayName`, `mainRace`, `winRate`, lenient decoding).
final class SC2PulseModelTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Characters

    func testCharactersFixtureDecodesAsLadderCharacters() throws {
        let data = try Fixtures.data("sc2pulse_characters")
        let characters = try decoder.decode([LadderCharacter].self, from: data)
        XCTAssertEqual(characters.count, 2)
    }

    func testLadderCharacterResolvesMmrFromCurrentStats() throws {
        let maru = try firstCharacter()
        // currentStats.rating is preferred over ratingMax.
        XCTAssertEqual(maru.mmr, 6653)
    }

    func testLadderCharacterFallsBackToRatingMaxWhenNoCurrentRating() throws {
        let json = Data("""
        [{
          "ratingMax": 5000,
          "members": {
            "terranGamesPlayed": 10,
            "character": { "id": 1, "tag": "Test", "region": "EU" }
          }
        }]
        """.utf8)
        let characters = try decoder.decode([LadderCharacter].self, from: json)
        XCTAssertEqual(characters.first?.mmr, 5000)
    }

    func testLadderCharacterResolvesMainRace() throws {
        let maru = try firstCharacter()
        // 721 Terran vs 35 Protoss → Terran.
        XCTAssertEqual(maru.mainRace, .terran)
    }

    func testLadderCharacterResolvesNameAndRank() throws {
        let maru = try firstCharacter()
        XCTAssertEqual(maru.name, "llllllllllll")
        XCTAssertEqual(maru.region, "EU")
        XCTAssertEqual(maru.rank, 59)
    }

    func testDisplayNamePrefersProNicknameOverBarcodeTag() throws {
        let maru = try firstCharacter()
        // The ladder tag is a barcode ("llllllllllll"); displayName must prefer "Maru".
        XCTAssertEqual(maru.name, "llllllllllll")
        XCTAssertEqual(maru.proNickname, "Maru")
        XCTAssertEqual(maru.displayName, "Maru")
    }

    func testDisplayNameFallsBackToNameWhenNoProNickname() throws {
        let json = Data("""
        [{
          "currentStats": { "rating": 4000, "rank": 1 },
          "members": {
            "zergGamesPlayed": 5,
            "character": { "id": 2, "tag": "PlainTag", "region": "US" }
          }
        }]
        """.utf8)
        let character = try XCTUnwrap(decoder.decode([LadderCharacter].self, from: json).first)
        XCTAssertNil(character.proNickname)
        XCTAssertEqual(character.displayName, "PlainTag")
        XCTAssertEqual(character.mainRace, .zerg)
    }

    func testCharacterAligulacIdIsNilWhenAbsent() throws {
        // Real Maru fixture has aligulacId == null.
        let maru = try firstCharacter()
        XCTAssertNil(maru.aligulacId)
    }

    // MARK: - Ladder

    func testLadderFixtureDecodesAsLadderTeamsWithWinRate() throws {
        let data = try Fixtures.data("sc2pulse_ladder")
        let teams = try decoder.decode([LadderTeam].self, from: data)
        XCTAssertEqual(teams.count, 3)

        let top = try XCTUnwrap(teams.first)
        XCTAssertEqual(top.rating, 6431)
        XCTAssertEqual(top.region, "EU")
        XCTAssertEqual(top.name, "Krystianer")
        XCTAssertEqual(top.mainRace, .protoss)

        // 102 wins / (102 + 44) losses.
        let winRate = try XCTUnwrap(top.winRate)
        XCTAssertEqual(winRate, 102.0 / 146.0, accuracy: 1e-9)
    }

    func testLadderTeamWinRateNilWhenNoGames() throws {
        let json = Data("""
        [{ "id": 1, "rating": 5000, "wins": 0, "losses": 0, "members": [] }]
        """.utf8)
        let teams = try decoder.decode([LadderTeam].self, from: json)
        XCTAssertNil(teams.first?.winRate)
    }

    // MARK: - Streams

    func testStreamsFixtureDecodesThroughWrapper() throws {
        struct Wrapper: Decodable { let streams: [LadderStream] }
        let data = try Fixtures.data("sc2pulse_streams")
        let wrapper = try decoder.decode(Wrapper.self, from: data)

        XCTAssertEqual(wrapper.streams.count, 3)
        let first = try XCTUnwrap(wrapper.streams.first)
        XCTAssertEqual(first.stream.userName, "Wintergaming")
        XCTAssertEqual(first.stream.viewerCount, 773)
        XCTAssertEqual(first.stream.service, "TWITCH")

        let totalViewers = wrapper.streams.reduce(0) { $0 + ($1.stream.viewerCount ?? 0) }
        XCTAssertEqual(totalViewers, 773 + 624 + 606)
    }

    func testStreamProPlayerLinkDecodes() throws {
        struct Wrapper: Decodable { let streams: [LadderStream] }
        let data = try Fixtures.data("sc2pulse_streams")
        let wrapper = try decoder.decode(Wrapper.self, from: data)

        let rotterdam = try XCTUnwrap(wrapper.streams.first { $0.stream.userName == "RotterdaM08" })
        XCTAssertEqual(rotterdam.proPlayer?.proPlayer?.nickname, "RotterdaM")
        XCTAssertEqual(rotterdam.proPlayer?.proPlayer?.aligulacId, 635)
    }

    // MARK: - Seasons

    func testSeasonsFixtureDecodes() throws {
        let data = try Fixtures.data("sc2pulse_seasons")
        let seasons = try decoder.decode([PulseSeason].self, from: data)
        XCTAssertEqual(seasons.count, 6)

        let kr = try XCTUnwrap(seasons.first)
        XCTAssertEqual(kr.id, 143822)
        XCTAssertEqual(kr.number, 2)
        XCTAssertEqual(kr.year, 2026)
        XCTAssertEqual(kr.region, "KR")
        XCTAssertEqual(kr.battlenetId, 67)
    }

    // MARK: - Lenient decoding

    func testFailableDecodableDropsGarbageElement() throws {
        // A good element followed by a structurally invalid one; the wrapper keeps the good.
        let json = Data("""
        [
          {
            "currentStats": { "rating": 4321, "rank": 7 },
            "members": {
              "terranGamesPlayed": 100,
              "character": { "id": 99, "tag": "Good", "region": "EU" }
            }
          },
          { "members": "this-should-be-an-object-not-a-string" }
        ]
        """.utf8)

        let wrapped = try decoder.decode([FailableDecodable<LadderCharacter>].self, from: json)
        let kept = wrapped.compactMap(\.value)
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.name, "Good")
        XCTAssertEqual(kept.first?.mmr, 4321)
    }

    func testFailableDecodableNeverThrowsOnFullyGarbageArray() throws {
        let json = Data("""
        [ 42, "nope", { "members": 7 } ]
        """.utf8)
        let wrapped = try decoder.decode([FailableDecodable<LadderCharacter>].self, from: json)
        XCTAssertTrue(wrapped.compactMap(\.value).isEmpty)
    }

    // MARK: - Helpers

    private func firstCharacter(file: StaticString = #filePath, line: UInt = #line) throws -> LadderCharacter {
        let data = try Fixtures.data("sc2pulse_characters")
        let characters = try decoder.decode([LadderCharacter].self, from: data)
        return try XCTUnwrap(characters.first, file: file, line: line)
    }
}
