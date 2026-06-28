import Foundation

/// Endpoint for tournament operations
public enum TournamentEndpoint: Endpoint {
    case all
    case past
    case running
    case upcoming

    public static var basePath: String {
        "/starcraft-2/tournaments"
    }

    public var subPath: String? {
        switch self {
        case .all: return nil
        case .past: return "past"
        case .running: return "running"
        case .upcoming: return "upcoming"
        }
    }
}

/// Tournament tier classification used by PandaScore (`a` is highest).
public enum TournamentTier: String, Sendable, CaseIterable {
    case s
    case a
    case b
    case c
    case d
}

/// API request for fetching tournaments
public struct TournamentsRequest: APIRequest {
    public typealias Response = [Tournament]

    public let endpoint: TournamentEndpoint
    public let queryParameters: [String: QueryValue]

    public var path: String {
        endpoint.fullPath
    }

    public init(
        endpoint: TournamentEndpoint = .all,
        parameters: QueryParameters = QueryParameters()
    ) {
        self.endpoint = endpoint
        self.queryParameters = parameters.toDictionary()
    }

    public init(
        endpoint: TournamentEndpoint = .all,
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil,
        filters: [String: QueryValue]? = nil,
        search: [String: String]? = nil,
        serieID: Int? = nil,
        leagueID: Int? = nil,
        tier: String? = nil
    ) {
        self.endpoint = endpoint

        var parameters = QueryParameters(
            pagination: PaginationParameters(page: page, size: pageSize),
            sort: sort,
            filters: filters,
            search: search
        )

        if let serieID {
            parameters = parameters.filter("serie_id", .int(serieID))
        }

        if let leagueID {
            parameters = parameters.filter("league_id", .int(leagueID))
        }

        if let tier {
            parameters = parameters.filter("tier", .string(tier))
        }

        self.queryParameters = parameters.toDictionary()
    }
}

/// API request for fetching a single tournament by id.
public struct TournamentRequest: APIRequest {
    public typealias Response = Tournament

    public let id: Int

    public var path: String {
        "\(TournamentEndpoint.basePath)/\(id)"
    }

    public var supportsPagination: Bool { false }

    public init(id: Int) {
        self.id = id
    }
}

// MARK: - Convenience Factory Methods
public extension TournamentsRequest {
    /// Request for past tournaments
    static func past(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> TournamentsRequest {
        TournamentsRequest(
            endpoint: .past,
            page: page,
            pageSize: pageSize,
            sort: sort ?? [SortParameter(field: "end_at", direction: .descending)]
        )
    }

    /// Request for running tournaments
    static func running(
        page: Int = 1,
        pageSize: Int = 50
    ) -> TournamentsRequest {
        TournamentsRequest(
            endpoint: .running,
            page: page,
            pageSize: pageSize
        )
    }

    /// Request for upcoming tournaments
    static func upcoming(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> TournamentsRequest {
        TournamentsRequest(
            endpoint: .upcoming,
            page: page,
            pageSize: pageSize,
            sort: sort ?? [SortParameter(field: "begin_at", direction: .ascending)]
        )
    }

    /// Get tournaments of a specific tier.
    static func byTier(
        _ tier: TournamentTier,
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> TournamentsRequest {
        TournamentsRequest(
            page: page,
            pageSize: pageSize,
            sort: sort,
            tier: tier.rawValue
        )
    }

    /// Get tournaments with prize pools
    static func withPrizePools(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> TournamentsRequest {
        TournamentsRequest(
            page: page,
            pageSize: pageSize,
            sort: sort,
            filters: ["has_prizepool": .bool(true)]
        )
    }
}
