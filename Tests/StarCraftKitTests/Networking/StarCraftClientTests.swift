import XCTest
@testable import StarCraftKit

/// End-to-end tests of the actor `StarCraftClient` over ``MockURLProtocol``: decoding a
/// real fixture into `[Match]`, surfacing API errors, and capturing rate-limit headers.
final class StarCraftClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test200DecodesMatches() async throws {
        let body = try Fixtures.data("matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = MockURLProtocol.makeClient()

        let matches = try await client.getMatches()
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.name, "Serral vs Maru")
        XCTAssertEqual(matches.first?.numberOfGames, 5)
    }

    func testBearerTokenHeaderApplied() async throws {
        MockURLProtocol.respond(status: 200, body: Data("[]".utf8))
        let client = MockURLProtocol.makeClient(authMethod: .bearerToken)

        _ = try await client.getMatches()

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }

    func testQueryParameterAuthAddsToken() async throws {
        MockURLProtocol.respond(status: 200, body: Data("[]".utf8))
        let client = MockURLProtocol.makeClient(authMethod: .queryParameter)

        _ = try await client.getMatches()

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(url.contains("token=test-token"), "expected token query param in \(url)")
    }

    func test401SurfacesUnauthorized() async {
        MockURLProtocol.respond(status: 401, body: Data("{}".utf8))
        let client = MockURLProtocol.makeClient()
        do {
            _ = try await client.getMatches()
            XCTFail("expected throw")
        } catch let error as APIError {
            guard case .unauthorized = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }

    func test404SurfacesNotFound() async {
        MockURLProtocol.respond(status: 404, body: Data("{}".utf8))
        let client = MockURLProtocol.makeClient()
        do {
            _ = try await client.getMatch(id: 99)
            XCTFail("expected throw")
        } catch let error as APIError {
            guard case .notFound = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }

    func testRateLimitStatusCapturedAfterRequest() async throws {
        MockURLProtocol.respond(status: 200, body: Data("[]".utf8), headers: ["X-Rate-Limit-Remaining": "42"])
        let client = MockURLProtocol.makeClient()

        _ = try await client.getMatches()
        let status = await client.getRateLimitStatus()
        XCTAssertEqual(status.remaining, 42)
    }

    func testDecodingErrorOnMalformedBody() async {
        MockURLProtocol.respond(status: 200, body: Data("not json".utf8))
        let client = MockURLProtocol.makeClient()
        do {
            _ = try await client.getMatches()
            XCTFail("expected throw")
        } catch let error as APIError {
            guard case .decodingError = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }
}
