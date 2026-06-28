import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StarCraftKit

/// Build a JSON array of `count` minimal matches with unique ids derived from `page`.
private func paginationMatchesJSON(count: Int, page: Int) -> Data {
    let objects = (0..<count).map { idx in
        #"{"id": \#(page * 1000 + idx), "status": "finished", "tournament_id": 1, "serie_id": 1, "games": [], "opponents": [], "results": []}"#
    }
    return Data("[\(objects.joined(separator: ","))]".utf8)
}

private func paginationPageNumber(from request: URLRequest) -> Int {
    guard let url = request.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let item = components.queryItems?.first(where: { $0.name == "page[number]" }),
          let value = item.value, let page = Int(value) else {
        return 1
    }
    return page
}

/// Verifies header-driven pagination: `executePaginated` accumulates pages and stops as
/// soon as the `X-Total` / page-fill heuristics say there is no more data, and
/// `executePage` surfaces the parsed `PaginationInfo`.
final class PaginationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private struct PagedMatchesRequest: APIRequest {
        typealias Response = [Match]
        let path = "/starcraft-2/matches"
        let cachePolicy: CachePolicy = .noCache
        let queryParameters: [String: QueryValue]
        init(pageSize: Int) {
            self.queryParameters = ["page[size]": .int(pageSize)]
        }
    }

    func testExecutePaginatedAccumulatesAcrossPagesAndStops() async throws {
        let pageSize = 50
        let total = 75

        MockURLProtocol.setHandler { request in
            let page = paginationPageNumber(from: request)
            let count = page == 1 ? pageSize : (total - pageSize)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "X-Page": "\(page)",
                    "X-Per-Page": "\(pageSize)",
                    "X-Total": "\(total)"
                ]
            )!
            return (response, paginationMatchesJSON(count: count, page: page))
        }

        let client = MockURLProtocol.makeClient()
        let all: [Match] = try await client.executePaginated(PagedMatchesRequest(pageSize: pageSize))

        XCTAssertEqual(all.count, total, "should accumulate every item across the two pages")
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "should stop after the second page; no wasted third request")
    }

    func testExecutePaginatedStopsOnEmptyPage() async throws {
        let pageSize = 50

        MockURLProtocol.setHandler { request in
            let page = paginationPageNumber(from: request)
            let count = page == 1 ? pageSize : 0
            let total = 1000
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "X-Page": "\(page)",
                    "X-Per-Page": "\(pageSize)",
                    "X-Total": "\(total)"
                ]
            )!
            return (response, paginationMatchesJSON(count: count, page: page))
        }

        let client = MockURLProtocol.makeClient()
        let all: [Match] = try await client.executePaginated(PagedMatchesRequest(pageSize: pageSize))

        XCTAssertEqual(all.count, pageSize)
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "page 2 is empty, so it stops there")
    }

    func testExecutePaginatedRespectsMaxPages() async throws {
        let pageSize = 10
        MockURLProtocol.setHandler { request in
            let page = paginationPageNumber(from: request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "X-Page": "\(page)",
                    "X-Per-Page": "\(pageSize)",
                    "X-Total": "10000"
                ]
            )!
            return (response, paginationMatchesJSON(count: pageSize, page: page))
        }

        let client = MockURLProtocol.makeClient()
        let all: [Match] = try await client.executePaginated(PagedMatchesRequest(pageSize: pageSize), maxPages: 3)

        XCTAssertEqual(all.count, 30)
        XCTAssertEqual(MockURLProtocol.requestCount, 3)
    }

    func testExecutePageSurfacesPaginationInfo() async throws {
        MockURLProtocol.respond(
            status: 200,
            body: paginationMatchesJSON(count: 25, page: 1),
            headers: [
                "X-Page": "2",
                "X-Per-Page": "25",
                "X-Total": "150"
            ]
        )

        let client = MockURLProtocol.makeClient()
        let (items, pagination): ([Match], PaginationInfo?) = try await client.executePage(PagedMatchesRequest(pageSize: 25))

        XCTAssertEqual(items.count, 25)
        let info = try XCTUnwrap(pagination)
        XCTAssertEqual(info.page, 2)
        XCTAssertEqual(info.perPage, 25)
        XCTAssertEqual(info.total, 150)
        XCTAssertEqual(info.totalPages, 6)
        XCTAssertTrue(info.hasNextPage)
        XCTAssertTrue(info.hasPreviousPage)
    }

    func testExecutePageReturnsNilPaginationWithoutHeaders() async throws {
        MockURLProtocol.respond(status: 200, body: paginationMatchesJSON(count: 3, page: 1))

        let client = MockURLProtocol.makeClient()
        let (items, pagination): ([Match], PaginationInfo?) = try await client.executePage(PagedMatchesRequest(pageSize: 25))

        XCTAssertEqual(items.count, 3)
        XCTAssertNil(pagination)
    }
}
