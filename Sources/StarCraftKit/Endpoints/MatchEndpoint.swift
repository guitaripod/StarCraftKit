import Foundation

/// Endpoint for match operations
public enum MatchEndpoint: Endpoint {
    case all
    case past
    case running
    case upcoming

    public static var basePath: String {
        "/starcraft-2/matches"
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

/// API request for fetching matches
public struct MatchesRequest: APIRequest {
    public typealias Response = [Match]

    public let endpoint: MatchEndpoint
    public let queryParameters: [String: QueryValue]

    public var path: String {
        endpoint.fullPath
    }

    public init(
        endpoint: MatchEndpoint = .all,
        parameters: QueryParameters = QueryParameters()
    ) {
        self.endpoint = endpoint
        self.queryParameters = parameters.toDictionary()
    }

    public init(
        endpoint: MatchEndpoint = .all,
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil,
        filters: [String: QueryValue]? = nil,
        search: [String: String]? = nil,
        status: MatchStatus? = nil,
        opponentID: Int? = nil,
        tournamentID: Int? = nil,
        serieID: Int? = nil,
        leagueID: Int? = nil
    ) {
        self.endpoint = endpoint

        var parameters = QueryParameters(
            pagination: PaginationParameters(page: page, size: pageSize),
            sort: sort,
            filters: filters,
            search: search
        )

        if let status {
            parameters = parameters.filter("status", .string(status.rawValue))
        }
        if let opponentID {
            parameters = parameters.filter("opponent_id", .int(opponentID))
        }
        if let tournamentID {
            parameters = parameters.filter("tournament_id", .int(tournamentID))
        }
        if let serieID {
            parameters = parameters.filter("serie_id", .int(serieID))
        }
        if let leagueID {
            parameters = parameters.filter("league_id", .int(leagueID))
        }

        self.queryParameters = parameters.toDictionary()
    }
}

/// API request for fetching a single match by id.
public struct MatchRequest: APIRequest {
    public typealias Response = Match

    public let id: Int

    public var path: String {
        "\(MatchEndpoint.basePath)/\(id)"
    }

    public var supportsPagination: Bool { false }

    public init(id: Int) {
        self.id = id
    }
}

// MARK: - Convenience Factory Methods
public extension MatchesRequest {
    /// Request for past matches
    static func past(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> MatchesRequest {
        MatchesRequest(
            endpoint: .past,
            page: page,
            pageSize: pageSize,
            sort: sort ?? [SortParameter(field: "end_at", direction: .descending)]
        )
    }

    /// Request for running matches
    static func running(
        page: Int = 1,
        pageSize: Int = 50
    ) -> MatchesRequest {
        MatchesRequest(
            endpoint: .running,
            page: page,
            pageSize: pageSize
        )
    }

    /// Request for upcoming matches
    static func upcoming(
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> MatchesRequest {
        MatchesRequest(
            endpoint: .upcoming,
            page: page,
            pageSize: pageSize,
            sort: sort ?? [SortParameter(field: "begin_at", direction: .ascending)]
        )
    }

    /// Request for a specific tournament's matches.
    static func forTournament(
        _ tournamentID: Int,
        page: Int = 1,
        pageSize: Int = 50,
        sort: [SortParameter]? = nil
    ) -> MatchesRequest {
        MatchesRequest(
            page: page,
            pageSize: pageSize,
            sort: sort,
            tournamentID: tournamentID
        )
    }
}
