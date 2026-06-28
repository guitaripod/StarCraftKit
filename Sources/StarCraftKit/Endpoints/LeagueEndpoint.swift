import Foundation

/// Endpoint for league operations
public enum LeagueEndpoint: Endpoint {
    case all

    public static var basePath: String {
        "/starcraft-2/leagues"
    }

    public var subPath: String? {
        nil
    }
}

/// API request for fetching leagues
public struct LeaguesRequest: APIRequest {
    public typealias Response = [League]

    public let queryParameters: [String: QueryValue]

    public var path: String {
        LeagueEndpoint.all.fullPath
    }

    public init(parameters: QueryParameters = QueryParameters()) {
        self.queryParameters = parameters.toDictionary()
    }

    public init(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil,
        filters: [String: QueryValue]? = nil,
        search: [String: String]? = nil
    ) {
        let parameters = QueryParameters(
            pagination: PaginationParameters(page: page, size: pageSize),
            sort: sort,
            filters: filters,
            search: search
        )
        self.queryParameters = parameters.toDictionary()
    }
}

/// API request for fetching a single league by id.
public struct LeagueRequest: APIRequest {
    public typealias Response = League

    public let id: Int

    public var path: String {
        "\(LeagueEndpoint.basePath)/\(id)"
    }

    public var supportsPagination: Bool { false }

    public init(id: Int) {
        self.id = id
    }
}

// MARK: - Convenience Factory Methods
public extension LeaguesRequest {
    /// Search for leagues by name
    static func searchByName(
        _ name: String,
        page: Int = 1,
        pageSize: Int = 50
    ) -> LeaguesRequest {
        LeaguesRequest(
            page: page,
            pageSize: pageSize,
            search: ["name": name]
        )
    }
}
