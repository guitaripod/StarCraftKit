import XCTest
@testable import StarCraftKit

/// Exercises the raw `NetworkingClient` HTTP layer through ``MockURLProtocol``:
/// status-code mapping, rate-limit capture, and `Retry-After` parsing.
final class NetworkingClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func send(status: Int, body: Data = Data("{}".utf8), headers: [String: String] = [:]) async throws -> (Data, [String: String]) {
        MockURLProtocol.respond(status: status, body: body, headers: headers)
        let client = MockURLProtocol.makeNetworkingClient()
        let request = try await client.buildRequest(path: "/probe", method: .get)
        return try await client.send(request)
    }

    func test200ReturnsBody() async throws {
        let body = Data(#"{"ok":true}"#.utf8)
        let (data, _) = try await send(status: 200, body: body)
        XCTAssertEqual(data, body)
    }

    func test401MapsToUnauthorized() async throws {
        await assertThrowsAPIError(status: 401) { error in
            guard case .unauthorized = error else { return XCTFail("expected .unauthorized, got \(error)") }
        }
    }

    func test403MapsToForbidden() async throws {
        await assertThrowsAPIError(status: 403) { error in
            guard case .forbidden = error else { return XCTFail("expected .forbidden, got \(error)") }
        }
    }

    func test404MapsToNotFound() async throws {
        await assertThrowsAPIError(status: 404) { error in
            guard case .notFound = error else { return XCTFail("expected .notFound, got \(error)") }
        }
    }

    func test429MapsToRateLimitExceeded() async throws {
        await assertThrowsAPIError(status: 429, headers: ["Retry-After": "120", "X-Rate-Limit-Remaining": "0"]) { error in
            guard case let .rateLimitExceeded(retryAfter, remaining) = error else {
                return XCTFail("expected .rateLimitExceeded, got \(error)")
            }
            XCTAssertEqual(retryAfter, 120)
            XCTAssertEqual(remaining, 0)
        }
    }

    func test500MapsToServerError() async throws {
        await assertThrowsAPIError(status: 500) { error in
            guard case let .serverError(statusCode, _) = error else {
                return XCTFail("expected .serverError, got \(error)")
            }
            XCTAssertEqual(statusCode, 500)
        }
    }

    func test400MapsToHTTPError() async throws {
        await assertThrowsAPIError(status: 400) { error in
            guard case let .httpError(statusCode, _) = error else {
                return XCTFail("expected .httpError, got \(error)")
            }
            XCTAssertEqual(statusCode, 400)
        }
    }

    func testRateLimitRemainingCaptured() async throws {
        MockURLProtocol.respond(status: 200, body: Data("[]".utf8), headers: ["X-Rate-Limit-Remaining": "873"])
        let client = MockURLProtocol.makeNetworkingClient()
        let request = try await client.buildRequest(path: "/probe", method: .get)
        _ = try await client.send(request)

        let status = await client.getRateLimitStatus()
        XCTAssertEqual(status.remaining, 873)
        XCTAssertNotNil(status.resetTime)
        XCTAssertGreaterThan(try XCTUnwrap(status.resetTime), Date())
    }

    // MARK: - parseRetryAfter

    func testParseRetryAfterDeltaSeconds() {
        XCTAssertEqual(NetworkingClient.parseRetryAfter("120"), 120)
        XCTAssertEqual(NetworkingClient.parseRetryAfter("  30  "), 30)
    }

    func testParseRetryAfterHTTPDate() throws {
        let future = Date().addingTimeInterval(300)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let httpDate = formatter.string(from: future)

        let parsed = try XCTUnwrap(NetworkingClient.parseRetryAfter(httpDate))
        XCTAssertEqual(parsed, 300, accuracy: 5)
    }

    func testParseRetryAfterNilAndEmpty() {
        XCTAssertNil(NetworkingClient.parseRetryAfter(nil))
        XCTAssertNil(NetworkingClient.parseRetryAfter(""))
        XCTAssertNil(NetworkingClient.parseRetryAfter("   "))
        XCTAssertNil(NetworkingClient.parseRetryAfter("not-a-date"))
    }

    // MARK: - Helpers

    private func assertThrowsAPIError(
        status: Int,
        headers: [String: String] = [:],
        file: StaticString = #filePath,
        line: UInt = #line,
        _ check: (APIError) -> Void
    ) async {
        MockURLProtocol.respond(status: status, body: Data("{}".utf8), headers: headers)
        let client = MockURLProtocol.makeNetworkingClient()
        do {
            let request = try await client.buildRequest(path: "/probe", method: .get)
            _ = try await client.send(request)
            XCTFail("expected throw for status \(status)", file: file, line: line)
        } catch let error as APIError {
            check(error)
        } catch {
            XCTFail("expected APIError, got \(error)", file: file, line: line)
        }
    }
}
