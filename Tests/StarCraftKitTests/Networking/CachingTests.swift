import XCTest
@testable import StarCraftKit

/// Verifies the response cache: identical cacheable GETs hit the network once, `.noCache`
/// always goes to the network, and `clearCache()` evicts everything.
final class CachingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// A request whose cache policy is configurable, so we can drive both branches.
    private struct CacheableMatchesRequest: APIRequest {
        typealias Response = [Match]
        let path = "/starcraft-2/matches"
        let cachePolicy: CachePolicy
        init(cachePolicy: CachePolicy = .useCache(ttl: 300)) {
            self.cachePolicy = cachePolicy
        }
    }

    func testIdenticalGetsHitNetworkOnce() async throws {
        let body = try Fixtures.data("matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = MockURLProtocol.makeClient()
        let request = CacheableMatchesRequest()

        let first: [Match] = try await client.execute(request)
        let second: [Match] = try await client.execute(request)

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "second identical GET should be served from cache")

        let stats = await client.getCacheStatistics()
        XCTAssertGreaterThanOrEqual(stats.hitCount, 1)
    }

    func testNoCachePolicyBypassesCache() async throws {
        let body = try Fixtures.data("matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = MockURLProtocol.makeClient()
        let request = CacheableMatchesRequest(cachePolicy: .noCache)

        _ = try await client.execute(request) as [Match]
        _ = try await client.execute(request) as [Match]

        XCTAssertEqual(MockURLProtocol.requestCount, 2, ".noCache must always hit the network")
    }

    func testClearCacheForcesRefetch() async throws {
        let body = try Fixtures.data("matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = MockURLProtocol.makeClient()
        let request = CacheableMatchesRequest()

        _ = try await client.execute(request) as [Match]
        XCTAssertEqual(MockURLProtocol.requestCount, 1)

        _ = try await client.execute(request) as [Match]
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "served from cache")

        await client.clearCache()

        _ = try await client.execute(request) as [Match]
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "cache cleared, must refetch")
    }

    func testCacheStatisticsTrackHitsAndMisses() async throws {
        let body = try Fixtures.data("matches")
        MockURLProtocol.respond(status: 200, body: body)
        let client = MockURLProtocol.makeClient()
        let request = CacheableMatchesRequest()

        _ = try await client.execute(request) as [Match]
        _ = try await client.execute(request) as [Match]

        let stats = await client.getCacheStatistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertGreaterThanOrEqual(stats.missCount, 1)
        XCTAssertGreaterThan(stats.hitRate, 0)
    }
}
