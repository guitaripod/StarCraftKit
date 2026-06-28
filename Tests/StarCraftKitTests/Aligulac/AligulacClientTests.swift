import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StarCraftKit

/// End-to-end tests of `AligulacClient` over ``MockURLProtocol`` — confirms the request
/// path, the `apikey` query injection, and response decoding all line up.
final class AligulacClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient() -> AligulacClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let config = AligulacClient.Configuration(
            apiKey: "aligulac-test-key",
            baseURL: URL(string: "https://mock.test/api/v1/")!,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: sessionConfig
        )
        return AligulacClient(configuration: config)
    }

    func testSearchPlayersDecodesAndInjectsAPIKey() async throws {
        let body = try Fixtures.data("aligulac_player")
        MockURLProtocol.respond(status: 200, body: body)
        let client = makeClient()

        let players = try await client.searchPlayers(tag: "Serral")
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.tag, "Serral")
        XCTAssertEqual(players.first?.race, .zerg)

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(url.contains("apikey=aligulac-test-key"), "apikey must be injected: \(url)")
        XCTAssertTrue(url.contains("player/"), "expected player path: \(url)")
    }

    func testRatingReturnsFirstObject() async throws {
        let body = try Fixtures.data("aligulac_rating")
        MockURLProtocol.respond(status: 200, body: body)
        let client = makeClient()

        let rating = try await client.rating(playerID: 485)
        XCTAssertEqual(rating?.ratingVsProtoss, 1.92)
        XCTAssertEqual(rating?.ratingVsZerg, 1.66)
    }

    func testPredictMatchDecodesNestedTags() async throws {
        let body = try Fixtures.data("aligulac_prediction")
        MockURLProtocol.respond(status: 200, body: body)
        let client = makeClient()

        let prediction = try await client.predictMatch(playerA: 485, playerB: 26, bestOf: 7)
        XCTAssertEqual(prediction.probabilityA, 0.62)
        XCTAssertEqual(prediction.probabilityB, 0.38)
        XCTAssertEqual(prediction.medianScoreA, 4)
        XCTAssertEqual(prediction.medianScoreB, 2)
        XCTAssertEqual(prediction.playerATag, "Serral")
        XCTAssertEqual(prediction.playerBTag, "Maru")

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(url.contains("predictmatch/485,26/"), "expected predictmatch path: \(url)")
        XCTAssertTrue(url.contains("bo=7"), "expected bo=7: \(url)")
    }

    func testHeadToHeadComputesWins() async throws {
        let body = try Fixtures.data("aligulac_matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = makeClient()

        // Fixture: player 485 vs player 26 across 3 matches.
        // m1: 485(3)-26(1) -> A win; m2: 26(2)-485(4) -> 485 win (A); m3: 485(1)-26(3) -> B win.
        let h2h = try await client.headToHead(playerA: 485, playerB: 26)
        XCTAssertEqual(h2h.winsA, 2)
        XCTAssertEqual(h2h.winsB, 1)
        XCTAssertEqual(try XCTUnwrap(h2h.winRateA), 2.0 / 3.0, accuracy: 0.0001)
    }

    func testAttributionIsPresent() {
        XCTAssertFalse(AligulacClient.attribution.isEmpty)
        XCTAssertTrue(AligulacClient.attribution.lowercased().contains("aligulac"))
    }
}
