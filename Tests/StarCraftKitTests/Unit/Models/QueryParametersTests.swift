import XCTest
@testable import StarCraftKit

final class QueryParametersTests: XCTestCase {
    func testPaginationParameters() {
        let pagination = PaginationParameters(page: 5, size: 150)
        XCTAssertEqual(pagination.page, 5)
        XCTAssertEqual(pagination.size, 100) // clamped to max 100

        let smallPagination = PaginationParameters(page: 0, size: 0)
        XCTAssertEqual(smallPagination.page, 1)
        XCTAssertEqual(smallPagination.size, 1)
    }

    func testSortParameter() {
        XCTAssertEqual(SortParameter(field: "name", direction: .ascending).toString(), "name")
        XCTAssertEqual(SortParameter(field: "created_at", direction: .descending).toString(), "-created_at")
    }

    func testRangeParameter() {
        XCTAssertEqual(RangeParameter(min: 10, max: 100).toString(), "10,100")
        XCTAssertEqual(RangeParameter(min: 50).toString(), "50,")
        XCTAssertEqual(RangeParameter(max: 200).toString(), ",200")
        XCTAssertEqual(RangeParameter(min: 10.5, max: 99.25).toString(), "10.5,99.25")
        XCTAssertEqual(RangeParameter().toString(), "")
    }

    // MARK: - Fluent API

    func testFluentBuildProducesCorrectKeysAndValues() {
        let params = QueryParameters()
            .page(2)
            .perPage(25)
            .sort("name", .ascending)
            .sort("age", .descending)
            .filter("status", .string("active"))
            .search("name", "John")
            .range("score", from: 80, to: 100)

        let dict = params.toDictionary()

        XCTAssertEqual(dict["page[number]"], .int(2))
        XCTAssertEqual(dict["page[size]"], .int(25))
        XCTAssertEqual(dict["sort"], .string("name,-age"))
        XCTAssertEqual(dict["filter[status]"], .string("active"))
        XCTAssertEqual(dict["search[name]"], .string("John"))
        XCTAssertEqual(dict["range[score]"], .string("80,100"))
    }

    func testFilterPreservesQueryValueTypes() {
        let params = QueryParameters()
            .filter("team_id", .int(123))
            .filter("active", .bool(true))
            .filter("name", "Serral")

        let dict = params.toDictionary()
        XCTAssertEqual(dict["filter[team_id]"], .int(123))
        XCTAssertEqual(dict["filter[active]"], .bool(true))
        XCTAssertEqual(dict["filter[name]"], .string("Serral"))
    }

    func testQueryValueLiteralConformances() {
        let params = QueryParameters()
            .filter("team_id", 123)   // integer literal -> .int
            .filter("active", true)   // boolean literal -> .bool
            .filter("name", "Serral") // string literal  -> .string

        let dict = params.toDictionary()
        XCTAssertEqual(dict["filter[team_id]"], .int(123))
        XCTAssertEqual(dict["filter[active]"], .bool(true))
        XCTAssertEqual(dict["filter[name]"], .string("Serral"))
    }

    func testMemberwiseInitToDictionary() {
        let params = QueryParameters(
            pagination: PaginationParameters(page: 1, size: 50),
            sort: [SortParameter(field: "date", direction: .descending)],
            filters: ["team_id": .int(123), "active": .bool(true)],
            search: ["player": "Serral"],
            ranges: ["rating": RangeParameter(min: 2000)]
        )

        let dict = params.toDictionary()
        XCTAssertEqual(dict["page[number]"], .int(1))
        XCTAssertEqual(dict["page[size]"], .int(50))
        XCTAssertEqual(dict["sort"], .string("-date"))
        XCTAssertEqual(dict["filter[team_id]"], .int(123))
        XCTAssertEqual(dict["filter[active]"], .bool(true))
        XCTAssertEqual(dict["search[player]"], .string("Serral"))
        XCTAssertEqual(dict["range[rating]"], .string("2000,"))
    }

    func testEmptyQueryProducesEmptyDictionary() {
        XCTAssertTrue(QueryParameters().toDictionary().isEmpty)
    }

    // MARK: - QueryValue encoding

    func testQueryValueQueryStrings() {
        XCTAssertEqual(QueryValue.string("hi").queryStrings, ["hi"])
        XCTAssertEqual(QueryValue.int(42).queryStrings, ["42"])
        XCTAssertEqual(QueryValue.bool(true).queryStrings, ["true"])
        XCTAssertEqual(QueryValue.bool(false).queryStrings, ["false"])
        XCTAssertEqual(QueryValue.double(2.5).queryStrings, ["2.5"])
        XCTAssertEqual(QueryValue.double(3.0).queryStrings, ["3"]) // whole doubles render without decimals
        XCTAssertEqual(QueryValue.list([.int(1), .int(2), .string("x")]).queryStrings, ["1", "2", "x"])
    }

    func testQueryValueScalarString() {
        XCTAssertEqual(QueryValue.list([.int(1), .int(2)]).scalarString, "1,2")
        XCTAssertEqual(QueryValue.string("solo").scalarString, "solo")
    }
}
