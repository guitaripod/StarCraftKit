import XCTest
import ArgumentParser
@testable import StarCraftKitCLI

/// ArgumentParser binding tests for the CLI commands. These parse argv into command
/// values and assert the option/argument wiring, without invoking `run()` (which would
/// require network access and a PANDA_TOKEN).
final class StarCraftKitCLITests: XCTestCase {

    // MARK: - predict

    func testPredictParsesPlayersAndBestOf() throws {
        let command = try PredictCommand.parse(["Serral", "Maru", "--best-of", "7"])
        XCTAssertEqual(command.playerA, "Serral")
        XCTAssertEqual(command.playerB, "Maru")
        XCTAssertEqual(command.bestOf, 7)
    }

    func testPredictBestOfShortFlag() throws {
        let command = try PredictCommand.parse(["Clem", "Reynor", "-b", "3"])
        XCTAssertEqual(command.bestOf, 3)
    }

    func testPredictBestOfDefault() throws {
        let command = try PredictCommand.parse(["Serral", "Maru"])
        XCTAssertEqual(command.bestOf, 5)
    }

    func testPredictRequiresTwoPlayers() {
        XCTAssertThrowsError(try PredictCommand.parse(["Serral"]))
    }

    // MARK: - head-to-head

    func testHeadToHeadParsesBothPlayers() throws {
        let command = try HeadToHeadCommand.parse(["Maru", "Serral"])
        XCTAssertEqual(command.playerA, "Maru")
        XCTAssertEqual(command.playerB, "Serral")
    }

    // MARK: - rating / ratings

    func testRatingParsesPlayer() throws {
        let command = try RatingCommand.parse(["Serral"])
        XCTAssertEqual(command.player, "Serral")
    }

    func testRatingsLimitDefaultAndOverride() throws {
        XCTAssertEqual(try RatingsCommand.parse([]).limit, 15)
        XCTAssertEqual(try RatingsCommand.parse(["--limit", "25"]).limit, 25)
        XCTAssertEqual(try RatingsCommand.parse(["-l", "10"]).limit, 10)
    }

    // MARK: - players

    func testPlayersParsesPaginationAndFilters() throws {
        let command = try PlayersCommand.parse([
            "--page", "3",
            "--size", "20",
            "--search", "Serral",
            "--nationality", "FI"
        ])
        XCTAssertEqual(command.page, 3)
        XCTAssertEqual(command.size, 20)
        XCTAssertEqual(command.search, "Serral")
        XCTAssertEqual(command.nationality, "FI")
    }

    func testPlayersDefaults() throws {
        let command = try PlayersCommand.parse([])
        XCTAssertEqual(command.page, 1)
        XCTAssertEqual(command.size, 10)
        XCTAssertNil(command.search)
        XCTAssertNil(command.nationality)
    }

    func testPlayersPageShortFlag() throws {
        let command = try PlayersCommand.parse(["-p", "2"])
        XCTAssertEqual(command.page, 2)
    }

    // MARK: - root command configuration

    func testRootCommandName() {
        XCTAssertEqual(StarCraftCLI.configuration.commandName, "starcraft")
        XCTAssertEqual(StarCraftCLI.configuration.version, "2.0.0")
    }

    func testRootHasSubcommands() {
        XCTAssertFalse(StarCraftCLI.configuration.subcommands.isEmpty)
        XCTAssertTrue(StarCraftCLI.configuration.subcommands.contains { $0 == PredictCommand.self })
        XCTAssertTrue(StarCraftCLI.configuration.subcommands.contains { $0 == PlayersCommand.self })
    }

    func testInvalidOptionThrows() {
        XCTAssertThrowsError(try PlayersCommand.parse(["--page", "not-a-number"]))
    }
}
